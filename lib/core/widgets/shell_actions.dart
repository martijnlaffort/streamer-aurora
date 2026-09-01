import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../platform/television.dart';

/// Search and Settings, as app-bar actions on the phone.
///
/// The bottom bar carries the places content lives; these two are tools, and
/// with seven destinations the bar had stopped being readable. Top-right is
/// also where a phone user looks for search.
///
/// Renders NOTHING on a television, where the same two live in the rail: a
/// second entry point would just be somewhere else for the D-pad to get lost,
/// and reaching the top-right corner from a poster grid is a long walk.
class ShellActions extends ConsumerWidget {
  const ShellActions({super.key, this.extra = const []});

  /// Screen-specific actions, shown before the shared pair.
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
