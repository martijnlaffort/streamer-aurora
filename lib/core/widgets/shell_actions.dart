import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart' show localMediaPlatformProvider;
import '../../features/local/local_playback.dart';
import '../platform/television.dart';

/// Open a file, Search and Settings, as app-bar actions on the phone.
///
/// The bottom bar carries the places content lives; these are tools, and
/// with seven destinations the bar had stopped being readable. Top-right is
/// also where a phone user looks for search.
///
/// Renders NOTHING on a television, where Search and Settings live in the
/// rail: a second entry point would just be somewhere else for the D-pad to
/// get lost, and reaching the top-right corner from a poster grid is a long
/// walk.
class ShellActions extends ConsumerWidget {
  const ShellActions({super.key, this.extra = const []});

  /// Screen-specific actions, shown before the shared ones.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isTelevisionOf(ref)) {
      return Row(mainAxisSize: MainAxisSize.min, children: extra);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...extra,
        if (ref.watch(localMediaPlatformProvider).isSupported)
          IconButton(
            tooltip: 'Open a video file',
            icon: const Icon(Icons.video_file_outlined),
            onPressed: () => pickAndPlayVideo(context, ref),
          ),
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          // `go`, not `push`: these are shell branches, so this switches tabs
          // rather than stacking a screen the bottom bar would then sit under.
          onPressed: () => context.go('/search'),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.go('/settings'),
        ),
      ],
    );
  }
}
