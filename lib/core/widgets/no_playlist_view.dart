import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart' show localMediaPlatformProvider;
import '../../features/local/local_playback.dart';
import '../platform/television.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// What every browse tab shows before there is a playlist or media server.
///
/// It used to be Home only. The other tabs said things like "No channels in
/// this playlist." — a dead end — and Home's button opened an EMPTY accounts
/// list that asked the same question again. The buttons here go straight to
/// the form (or, on a TV, to pairing, since typing a server address with a
/// D-pad is exactly what pairing exists to avoid).
class NoPlaylistView extends StatelessWidget {
  const NoPlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: GetStartedOptions(),
        ),
      ),
    );
  }
}

/// The three ways in, in the order most people need them: a video already on
/// the device, then a playlist, then a media server.
class GetStartedOptions extends ConsumerWidget {
  const GetStartedOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = isTelevisionOf(ref);
    final files = !tv && ref.watch(localMediaPlatformProvider).isSupported;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dawn Player',
              textAlign: TextAlign.center, style: AppTypography.display),
          const SizedBox(height: 8),
          Text(
            tv
                ? 'Pair with your phone to bring your playlists across.'
                : 'Play the videos on this device, or a playlist or media '
                    'server of your own.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (tv) ...[
            FilledButton.icon(
              autofocus: true,
              onPressed: () => context.push('/pair/receive'),
              icon: const Icon(Icons.phonelink_ring),
              label: const Text('Pair with your phone'),
            ),
            const SizedBox(height: 8),
          ],
          if (files) ...[
            FilledButton.icon(
              onPressed: () => pickAndPlayVideo(context, ref),
              icon: const Icon(Icons.video_file_outlined),
              label: const Text('Open a video file'),
            ),
            const SizedBox(height: 8),
          ],
          _option(
            context,
            primary: !tv && !files,
            icon: Icons.playlist_add,
            label: 'Add a playlist link or file',
            onPressed: () => context.push('/accounts/add?kind=playlist'),
          ),
          const SizedBox(height: 8),
          _option(
            context,
            primary: false,
            icon: Icons.dns_outlined,
            label: 'Connect a media server',
            onPressed: () => context.push('/accounts/add?kind=server'),
          ),
          const SizedBox(height: 16),
          Text(
            'Dawn Player includes no content.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required bool primary,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) =>
      primary
          ? FilledButton.icon(
              onPressed: onPressed, icon: Icon(icon), label: Text(label))
          : OutlinedButton.icon(
              onPressed: onPressed, icon: Icon(icon), label: Text(label));
}
