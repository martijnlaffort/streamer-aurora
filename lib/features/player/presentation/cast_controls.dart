import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/cast/cast_service.dart';
import '../../../data/cast/cast_url.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart' show StreamRef;
import 'cast_picker.dart';

/// Casting beyond the player: a "cast this" button for the detail screens, a
/// persistent mini bar for the browse shell, and a remote sheet to drive a cast
/// that was started outside the player. The player keeps its own in-screen
/// casting view; these let a user start and control a cast without ever opening
/// local playback first.

/// Debug-only override that forces the cast affordances visible so they can be
/// exercised where the Cast SDK is not present — chiefly an emulator, which has
/// no Play Services Cast, so `castAvailable` is always false there and none of
/// the buttons would otherwise appear. Set with `--dart-define=DAWN_FORCE_CAST=
/// true`; ignored in release builds, exactly like [DAWN_FORCE_TV]. Note it only
/// reveals the ENTRY points — a real receiver is still needed for a session, so
/// the mini bar and remote sheet stay empty until something actually casts.
const _forceCastFlag =
    bool.fromEnvironment('DAWN_FORCE_CAST', defaultValue: false);

/// Whether to OFFER casting in the UI. The SDK being present is not enough: on
/// the television build you are already on the big screen, so casting is
/// pointless there and the affordance is hidden. Mirrors the player's own guard
/// (see PlayerScreen.initState) so the button appears in exactly the same cases.
final castOfferedProvider = FutureProvider<bool>((ref) async {
  if (!kReleaseMode && _forceCastFlag) return true;
  if (await ref.watch(isTelevisionProvider.future)) return false;
  return ref.watch(castAvailableProvider.future);
});

/// The title/subtitle of whatever is currently being cast.
///
/// The receiver's status stream carries the transport state and position but not
/// the metadata, so the app remembers what it handed over. Set when a cast
/// starts (here and in the player); read by the mini bar and the remote sheet so
/// they can name the thing on the TV rather than just "Casting".
class CastNowPlaying extends Notifier<({String title, String? subtitle})?> {
  @override
  ({String title, String? subtitle})? build() => null;

  void set(String title, String? subtitle) =>
      state = (title: title, subtitle: subtitle);

  void clear() => state = null;
}

final castNowPlayingProvider =
    NotifierProvider<CastNowPlaying, ({String title, String? subtitle})?>(
        CastNowPlaying.new);

/// Hands [streamRef] to a Chromecast from anywhere in the app.
///
/// Mirrors the player's own hand-off (PlayerScreen._startCasting) so the two
/// entry points behave identically: an uncastable container is refused with a
/// message rather than failing silently at the receiver; a device is picked only
/// when none is connected yet (otherwise the stream just replaces what the TV is
/// already playing); and the remote sheet opens on success. Returns true when
/// the receiver was handed the stream.
Future<bool> beginCast(
  BuildContext context,
  WidgetRef ref, {
  required StreamRef streamRef,
  required String title,
  String? subtitle,
  bool isLive = false,
  int positionSeconds = 0,
}) async {
  final account = await ref.read(activeAccountProvider.future);
  if (!context.mounted || account == null) return false;

  final String url;
  try {
    url =
        await ref.read(sourceFactoryProvider)(account).buildStreamUrl(streamRef);
  } on Object catch (e) {
    if (context.mounted) _toast(context, '$e');
    return false;
  }
  if (!context.mounted) return false;

  // "Can this be cast?" is entirely a question about the container — decided in
  // one place, the same one the player uses.
  final target = castTargetFor(streamRef, url);
  if (!target.canCast) {
    _toast(context, target.refusal!);
    return false;
  }

  final alreadyCasting = ref.read(castStatusProvider).value?.isCasting ?? false;
  if (!alreadyCasting) {
    final picked = await showCastPicker(context);
    if (!context.mounted || picked != true) return false;
  }

  ref.read(castNowPlayingProvider.notifier).set(title, subtitle);
  try {
    await ref.read(castServiceProvider).load(
          url: target.url!,
          contentType: target.contentType!,
          isLive: target.isLive,
          title: title,
          subtitle: subtitle,
          positionSeconds: isLive ? 0 : positionSeconds,
        );
  } on PlatformException catch (e) {
    if (context.mounted) {
      _toast(context, e.message ?? 'That device would not accept the stream.');
    }
    return false;
  }
  if (context.mounted) showCastRemote(context);
  return true;
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// App-bar / action-row button that starts casting the given stream, or — when a
/// cast is already running — re-opens the remote to control it. Hides itself
/// entirely where casting is not offered (iOS, desktop, the TV build, or no Cast
/// SDK), so call sites can drop it in without their own guard.
class CastButton extends ConsumerWidget {
  const CastButton({
    super.key,
    required this.streamRef,
    required this.title,
    this.subtitle,
    this.isLive = false,
    this.positionSeconds = 0,
  });

  final StreamRef streamRef;
  final String title;
  final String? subtitle;
  final bool isLive;
  final int positionSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offered = ref.watch(castOfferedProvider).value ?? false;
    if (!offered) return const SizedBox.shrink();
    final casting = ref.watch(castStatusProvider).value?.isCasting ?? false;
    return IconButton(
      tooltip: casting ? 'Casting' : 'Cast to a TV',
      color: casting ? AppColors.accent : null,
      icon: Icon(casting ? Icons.cast_connected : Icons.cast),
      onPressed: () {
        if (casting) {
          showCastRemote(context);
        } else {
          beginCast(context, ref,
              streamRef: streamRef,
              title: title,
              subtitle: subtitle,
              isLive: isLive,
              positionSeconds: positionSeconds);
        }
      },
    );
  }
}

/// Slim bar that sits above the browse shell's navigation while a cast is
/// running, so control does not vanish the moment the user leaves the screen
/// they cast from. Tapping it opens the full remote. Renders nothing when
/// nothing is casting.
class CastMiniBar extends ConsumerWidget {
  const CastMiniBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(castStatusProvider).value ?? const CastStatus();
    if (!status.isCasting) return const SizedBox.shrink();
    final nowPlaying = ref.watch(castNowPlayingProvider);
    final service = ref.read(castServiceProvider);

    return Material(
      color: AppColors.surfaceElevated,
      child: InkWell(
        onTap: () => showCastRemote(context),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.background.withValues(alpha: 0.6))),
          ),
          child: Row(
            children: [
              Icon(Icons.cast_connected, color: AppColors.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nowPlaying?.title ?? 'Casting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      status.deviceName == null
                          ? 'Connected'
                          : 'On ${status.deviceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!status.isPlaying && status.state != CastState.buffering)
                IconButton(
                  tooltip: 'Play',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: service.play,
                )
              else
                IconButton(
                  tooltip: 'Pause',
                  icon: const Icon(Icons.pause),
                  onPressed: service.pause,
                ),
              IconButton(
                tooltip: 'Stop casting',
                icon: const Icon(Icons.stop),
                onPressed: service.disconnect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the remote-control sheet for the current cast. Used by the mini bar,
/// the cast button when already connected, and right after a cast starts.
Future<void> showCastRemote(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => const SafeArea(child: _CastRemote()),
  );
}

/// The full remote: this device becomes the controller for whatever is on the
/// TV. Driven entirely by the receiver's status stream, so it works for casts
/// started from a detail screen with no player ever having opened.
class _CastRemote extends ConsumerStatefulWidget {
  const _CastRemote();

  @override
  ConsumerState<_CastRemote> createState() => _CastRemoteState();
}

class _CastRemoteState extends ConsumerState<_CastRemote> {
  /// While the user drags the scrubber, show their position rather than the
  /// receiver's — otherwise every status tick would yank the thumb back.
  double? _dragSeconds;

  @override
  Widget build(BuildContext context) {
    // Close the sheet the moment the cast ends (the user pressed stop, or the
    // receiver dropped), so it can't sit open controlling nothing.
    ref.listen<AsyncValue<CastStatus>>(castStatusProvider, (prev, next) {
      final casting = next.value?.isCasting ?? false;
      if (!casting && Navigator.canPop(context)) Navigator.pop(context);
    });

    final status = ref.watch(castStatusProvider).value ?? const CastStatus();
    final nowPlaying = ref.watch(castNowPlayingProvider);
    final service = ref.read(castServiceProvider);
    // Live has no meaningful scrubber; VOD gets one once the receiver reports a
    // duration.
    final showScrubber = status.durationSeconds > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cast_connected, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status.deviceName == null
                      ? 'Casting'
                      : 'Casting to ${status.deviceName}',
                  style: AppTypography.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (nowPlaying != null) ...[
            const SizedBox(height: 16),
            Text(nowPlaying.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (nowPlaying.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(nowPlaying.subtitle!,
                  style: TextStyle(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
          const SizedBox(height: 20),
          if (showScrubber) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: (_dragSeconds ?? status.positionSeconds.toDouble())
                    .clamp(0.0, status.durationSeconds.toDouble()),
                max: status.durationSeconds.toDouble(),
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() => _dragSeconds = v),
                onChangeEnd: (v) {
                  service.seek(v.round());
                  setState(() => _dragSeconds = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      formatSeconds(
                          (_dragSeconds ?? status.positionSeconds.toDouble())
                              .round()),
                      style: TextStyle(color: AppColors.textSecondary)),
                  Text(formatSeconds(status.durationSeconds),
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showScrubber)
                IconButton(
                  iconSize: 34,
                  tooltip: 'Back 10 seconds',
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => service.seek(
                      (status.positionSeconds - 10).clamp(0, 1 << 30)),
                ),
              const SizedBox(width: 8),
              _PlayPause(status: status, service: service),
              const SizedBox(width: 8),
              if (showScrubber)
                IconButton(
                  iconSize: 34,
                  tooltip: 'Forward 10 seconds',
                  icon: const Icon(Icons.forward_10),
                  onPressed: () =>
                      service.seek(status.positionSeconds + 10),
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => service.disconnect(),
            icon: const Icon(Icons.stop),
            label: const Text('Stop casting'),
          ),
        ],
      ),
    );
  }
}

class _PlayPause extends StatelessWidget {
  const _PlayPause({required this.status, required this.service});

  final CastStatus status;
  final CastService service;

  @override
  Widget build(BuildContext context) {
    if (status.state == CastState.buffering) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final playing = status.isPlaying;
    return IconButton.filled(
      iconSize: 40,
      tooltip: playing ? 'Pause' : 'Play',
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      onPressed: playing ? service.pause : service.play,
    );
  }
}
