import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../data/local/local_files_repository.dart';
import '../../data/local/local_media_platform.dart';
import '../../data/providers.dart';
import '../home/home_providers.dart';
import '../player/player_request.dart';

/// The player item for a file on this device.
///
/// A film in every respect that matters: it resumes, it remembers the audio and
/// subtitle language, and it appears in Continue Watching. The player turns its
/// [StreamRef] back into a path through [LocalMediaPlatform.resolve], so the
/// same item still plays after a restart.
PlayerItem localPlayerItem(LocalFile file) => PlayerItem(
      streamRef: file.streamRef,
      title: file.title,
      contentKey: file.contentKey,
    );

void _say(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "Open a video file": the system document picker, then straight into the
/// player.
Future<void> pickAndPlayVideo(BuildContext context, WidgetRef ref) async {
  final platform = ref.read(localMediaPlatformProvider);
  if (!platform.isSupported) {
    _say(context, 'Opening files is not available on this device.');
    return;
  }
  final pick = await platform.pickVideo();
  if (pick == null || !context.mounted) return;
  await playLocalPick(context, ref, pick);
}

/// Plays a file the system just handed over (picker, Files, share sheet).
Future<void> playLocalPick(
    BuildContext context, WidgetRef ref, LocalMediaPick pick) async {
  final file = await ref.read(localFilesRepositoryProvider).recordOpened(pick);
  if (!context.mounted) return;
  ref.invalidate(localFilesProvider);
  await playLocalFile(context, ref, file);
}

/// Plays a remembered file. Stored progress is picked up by the player itself,
/// so a file opened again tomorrow carries on where it stopped.
Future<void> playLocalFile(
    BuildContext context, WidgetRef ref, LocalFile file) async {
  await ref.read(appRouterProvider).push(
        '/player',
        extra: PlayerRequest(queue: [localPlayerItem(file)]),
      );
  if (!context.mounted) return;
  ref.invalidate(localFilesProvider);
  ref.invalidate(homeDataProvider);
}
