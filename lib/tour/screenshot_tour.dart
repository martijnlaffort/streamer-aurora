/// The App Store's 6.9" screenshot slot only accepts 1320×2868, and the
/// development iPhone is a 6.3" (1206×2622). Rather than fake the difference by
/// compositing real captures into designed frames, the screenshots are taken on
/// an iPhone Pro Max simulator that is exactly that size — which means something
/// has to drive the app, because there is no Mac to drive it by hand.
///
/// This is that driver. Enabled only by `--dart-define=DAWN_TOUR=true`, it adds
/// the review demo playlist, walks the screens worth showing, and prints a marker line
/// at each stop. `.github/workflows/ios-screenshots.yml` watches stdout for
/// those markers and runs `xcrun simctl io … screenshot` when it sees one —
/// which captures the composited screen, video surface and all, where a
/// Flutter-side screenshot would give a black rectangle where the player is.
///
/// It is a capture harness, not a test: nothing here asserts anything, and a
/// stop that fails is logged and skipped so the rest of the run still produces
/// its images.
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../data/db/app_database.dart' show CatalogKind;
import '../data/providers.dart';
import '../domain/models/models.dart';
import '../features/home/home_providers.dart' show homeDataProvider;
import '../features/player/player_request.dart';

/// Whether this build is a screenshot run. Const, so a normal build compiles
/// the tour out entirely.
const bool screenshotTourEnabled = bool.fromEnvironment('DAWN_TOUR');

/// The demo playlist: the same one App Review is given, so every screenshot
/// shows exactly what a reviewer will see — two Blender films, both CC BY and
/// hosted on dawnplayer.com, and nothing anybody else owns.
const String _playlist = String.fromEnvironment(
  'DAWN_TOUR_PLAYLIST',
  defaultValue: 'https://dawnplayer.com/demo/demo.m3u',
);

/// Set by the player while it is on screen: opens its Audio & subtitles panel.
/// Nothing taps the simulator, so this is how the tour gets the panel open.
void Function()? tourOpenLanguages;

/// How long a screen gets to settle (network, artwork, first paint) before its
/// marker is printed.
const Duration _settle = Duration(seconds: 5);

/// How long the app then holds still.
///
/// Generous on purpose. The watcher reads markers out of a log the Flutter tool
/// is still writing to, and `simctl io screenshot` itself takes seconds — the
/// first one after boot took seven. A four-second hold meant the capture landed
/// on the *next* screen, and the home shot came out as the live list.
const Duration _hold = Duration(seconds: 12);

void _log(String message) {
  // ignore: avoid_print
  print('DAWN_TOUR_LOG $message');
}

/// [landscape] tells the watcher to rotate the capture. The player locks the
/// device to landscape, but `simctl` photographs the framebuffer in its
/// physical orientation, so the frame comes back portrait with the UI on its
/// side.
Future<void> _capture(String name, {bool landscape = false, Duration? hold}) async {
  // ignore: avoid_print
  print('DAWN_SHOT:$name${landscape ? ' LANDSCAPE' : ''}');
  await Future<void>.delayed(hold ?? _hold);
}

/// Runs the whole tour and prints `DAWN_TOUR_DONE` when there is nothing more
/// to capture — which is the watcher's signal to stop and the job's to finish.
Future<void> runScreenshotTour(ProviderContainer container) async {
  try {
    final router = container.read(appRouterProvider);
    // A debug build can take longer than the tour to rasterise its first
    // frame — one run photographed the launch screen and called it home.
    // Waiting on a completed frame is the honest signal; the cushion covers
    // fonts after it.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 4));

    // First, before anything is added: the getting-started screen with its
    // three ways in, files first.
    await _stop(router, '/', 'welcome');

    final account = await _seed(container);
    await _stop(router, '/movies', 'movies');
    await _stop(router, '/', 'continue');
    await _languages(router, container, account);
  } catch (error) {
    _log('FAILED $error');
  } finally {
    // ignore: avoid_print
    print('DAWN_TOUR_DONE');
  }
}

/// Adds the demo playlist the way the add screen would, then leaves both films
/// part-watched, inside the §8.9 resume window, so Continue Watching has
/// something in it.
Future<Account> _seed(ProviderContainer container) async {
  final account = Account(
    id: stableAccountId(
      type: AccountType.m3u,
      serverUrl: _playlist,
      username: '',
    ),
    type: AccountType.m3u,
    name: 'Demo',
    serverUrl: _playlist,
    username: '',
    password: '',
    createdAt: DateTime.now().toUtc(),
  );

  final accounts = container.read(accountRepositoryProvider);
  await accounts.saveAccount(account);
  await accounts.setActiveAccount(account.id);
  container.invalidate(accountsProvider);
  container.invalidate(activeAccountProvider);
  _log('playlist seeded from $_playlist');

  final catalog = container.read(catalogRepositoryProvider);
  for (final kind in CatalogKind.values) {
    try {
      await catalog.prepareSlice(account, kind);
      _log('cached ${kind.name}');
    } catch (error) {
      // A playlist has no series, and this one no live streams.
      _log('nothing for ${kind.name}: $error');
    }
  }
  container.invalidate(activeHasLiveProvider);

  final progress = container.read(watchProgressRepositoryProvider);
  final films = await catalog.movies(account, limit: 10);
  for (final film in films) {
    final sintel = film.name.toLowerCase().contains('sintel');
    await progress.savePosition(
      contentKey: contentKeyFor(
        accountId: account.id,
        type: StreamType.movie,
        id: film.id,
      ),
      // Real running times, so the progress bars are honest.
      positionSeconds: sintel ? 300 : 230,
      durationSeconds: sintel ? 888 : 634,
    );
  }
  container.invalidate(homeDataProvider);
  _log('${films.length} films left part-watched');

  return account;
}

Future<void> _stop(
  GoRouter router,
  String location,
  String name, {
  Duration? settle,
}) async {
  try {
    router.go(location);
    await Future<void>.delayed(settle ?? _settle);
    await _capture(name);
  } catch (error) {
    _log('stop $name failed: $error');
  }
}

/// Sintel playing, with the Audio & subtitles panel open on its subtitle
/// languages: the language memory the listing leads with, on a CC BY film.
Future<void> _languages(
  GoRouter router,
  ProviderContainer container,
  Account account,
) async {
  try {
    final films = await container
        .read(catalogRepositoryProvider)
        .movies(account, limit: 10);
    final sintel = films
        .where((f) => f.name.toLowerCase().contains('sintel'))
        .firstOrNull;
    if (sintel == null) {
      _log('Sintel is not in the playlist — skipping the languages shot');
      return;
    }
    router.push(
      '/player',
      extra: PlayerRequest(
        queue: [
          PlayerItem(
            streamRef: StreamRef(
              accountId: account.id,
              type: StreamType.movie,
              streamId: sintel.id,
              containerExt: sintel.containerExt,
            ),
            title: sintel.name,
            contentKey: contentKeyFor(
              accountId: account.id,
              type: StreamType.movie,
              id: sintel.id,
            ),
          ),
        ],
        // Past the opening titles, onto footage behind the panel.
        resumeFromSeconds: 300,
      ),
    );
    // Rotate, open the stream, decode a frame (in software on a simulator)
    // and report the tracks: the panel lists only what mpv has found.
    await Future<void>.delayed(const Duration(seconds: 14));
    final open = tourOpenLanguages;
    if (open == null) {
      _log('player not on screen — skipping the languages shot');
      return;
    }
    open();
    await Future<void>.delayed(const Duration(seconds: 2));
    // Grabbing the framebuffer while video composites is slow: hold long.
    await _capture('languages',
        landscape: true, hold: const Duration(seconds: 30));
    router.pop(); // the panel
    router.pop(); // the player
  } catch (error) {
    _log('languages stop failed: $error');
  }
}
