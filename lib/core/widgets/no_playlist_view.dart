import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../platform/television.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// What every browse tab shows before there is a playlist.
///
/// It used to be Home only. The other tabs said things like "No channels in
/// this playlist." — a dead end — and Home's button opened an EMPTY accounts
/// list that asked the same question again. The buttons here go straight to
/// the form (or, on a TV, to pairing, since typing a server address with a
/// D-pad is exactly what pairing exists to avoid).
class NoPlaylistView extends ConsumerWidget {
  const NoPlaylistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = isTelevisionOf(ref);
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dawn Player', style: AppTypography.display),
              const SizedBox(height: 8),
              Text(
                tv
                    ? 'Pair with your phone to bring your playlists across.'
                    : 'Add the playlist your provider sent you to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (tv) ...[
                FilledButton.icon(
                  autofocus: true,
                  onPressed: () => context.push('/pair/receive'),
                  icon: const Icon(Icons.phonelink_ring),
                  label: const Text('Pair with your phone'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push('/accounts/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Or add a playlist manually'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => context.push('/accounts/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a playlist'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
