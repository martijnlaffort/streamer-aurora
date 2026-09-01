/// The App Store's 6.9" screenshot slot only accepts 1320×2868, and the
/// development iPhone is a 6.3" (1206×2622). Rather than fake the difference by
/// compositing real captures into designed frames, the screenshots are taken on
/// an iPhone Pro Max simulator that is exactly that size — which means something
/// has to drive the app, because there is no Mac to drive it by hand.
///
/// This is that driver. Enabled only by `--dart-define=DAWN_TOUR=true`, it seeds
/// the demo account, walks the screens worth showing, and prints a marker line
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

/// The mock panel. The workflow runs `tool/mock_xtream.php` on the runner
/// itself — the simulator shares the host's loopback — so no screenshot depends
/// on demo.dawnplayer.com being up, and none of them can show a real provider.
const String _server = String.fromEnvironment(
  'DAWN_TOUR_SERVER',
  defaultValue: 'http://127.0.0.1:8082',
);

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
Future<void> _capture(String name, {bool landscape = false}) async {
  // ignore: avoid_print
  print('DAWN_SHOT:$name${landscape ? ' LANDSCAPE' : ''}');
  await Future<void>.delayed(_hold);
}

/// Runs the whole tour and prints `DAWN_TOUR_DONE` when there is nothing more
/// to capture — which is the watcher's signal to stop and the job's to finish.
Future<void> runScreenshotTour(ProviderContainer container) async {
  try {
    // Let the first frame land before touching providers that build a database.
    await Future<void>.delayed(const Duration(seconds: 2));
    final account = await _seed(container);
    await _walk(container, account);
  } catch (error) {
    _log('FAILED $error');
  } finally {
    // ignore: avoid_print
    print('DAWN_TOUR_DONE');
  }
}

/// Adds the demo account the way the Add account screen would, then fills the
/// cache: catalogue, guide, and enough watch progress that Continue Watching is
/// not an empty row in the one screenshot everybody looks at.
Future<Account> _seed(ProviderContainer container) async {
  final account = Account(
    id: stableAccountId(
      type: AccountType.xtream,
      serverUrl: _server,
      username: 'aurora',
    ),
    type: AccountType.xtream,
    name: 'Demo line',
    serverUrl: _server,
    username: 'aurora',
    password: 'test',
    createdAt: DateTime.now().toUtc(),
  );

  final accounts = container.read(accountRepositoryProvider);
  await accounts.saveAccount(account);
  await accounts.setActiveAccount(account.id);
  container.invalidate(accountsProvider);
  container.invalidate(activeAccountProvider);
  _log('account seeded against $_server');

  final catalog = container.read(catalogRepositoryProvider);
  for (final kind in CatalogKind.values) {
    await catalog.prepareSlice(account, kind);
    _log('cached ${kind.name}');
  }

  try {
    await container.read(epgRepositoryProvider).refreshGuide(account, force: true);
    _log('guide ingested');
  } catch (error) {
    _log('guide failed: $error');
  }

  // Three part-watched films. Positions sit inside the §8.9 resume window
  // (5%–95%), because outside it the app is right to offer nothing.
  final progress = container.read(watchProgressRepositoryProvider);
  final films = await catalog.movies(account, limit: 3);
  for (final (index, film) in films.indexed) {
    await progress.savePosition(
      contentKey: contentKeyFor(
        accountId: account.id,
        type: StreamType.movie,
        id: film.id,
      ),
      positionSeconds: 900 + index * 600,
      durationSeconds: 5400,
    );
  }
  container.invalidate(homeDataProvider);
  _log('${films.length} films left part-watched');

  return account;
}

Future<void> _walk(ProviderContainer container, Account account) async {
  final router = container.read(appRouterProvider);
  final catalog = container.read(catalogRepositoryProvider);

  await _stop(router, '/', 'home');
  await _stop(router, '/live', 'live');
  await _stop(router, '/guide', 'guide');
  await _stop(router, '/movies', 'movies');

  final series = await catalog.series(account, limit: 1);
  if (series.isNotEmpty) {
    await _stop(router, '/series/${series.first.id}', 'series');
  } else {
    _log('no series cached — skipping the series shot');
  }

  await _player(router, container, account);
}

Future<void> _stop(GoRouter router, String location, String name) async {
  try {
    router.go(location);
    await Future<void>.delayed(_settle);
    await _capture(name);
  } catch (error) {
    _log('stop $name failed: $error');
  }
}

/// The player, on a film rather than a live channel: Big Buck Bunny is Creative
/// Commons, so the one screenshot showing video shows nothing anybody else owns
/// — and a film also gets the seek bar into the frame, which live playback hides.
Future<void> _player(
  GoRouter router,
  ProviderContainer container,
  Account account,
) async {
  try {
    final films =
        await container.read(catalogRepositoryProvider).movies(account, limit: 1);
    if (films.isEmpty) {
      _log('no films cached — skipping the player shot');
      return;
    }
    final film = films.first;
    router.push(
      '/player',
      extra: PlayerRequest(
        queue: [
          PlayerItem(
            streamRef: StreamRef(
              accountId: account.id,
              type: StreamType.movie,
              streamId: film.id,
              containerExt: film.containerExt,
            ),
            title: film.name,
            contentKey: contentKeyFor(
              accountId: account.id,
              type: StreamType.movie,
              id: film.id,
            ),
          ),
        ],
      ),
    );
    // The device rotates, the stream opens, and mpv decodes a frame — in
    // software on a simulator, since videotoolbox has no hardware to hand.
    // Measured at about five and a half seconds. Waiting much longer than that
    // is not free: the demo clip runs ten seconds, and a screenshot taken at
    // 0:09 of 0:10 shows a play button over a stopped film.
    await Future<void>.delayed(const Duration(seconds: 11));
    await _capture('player', landscape: true);
    router.pop();
  } catch (error) {
    _log('player stop failed: $error');
  }
}
