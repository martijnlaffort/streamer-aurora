import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../platform/television.dart';
import '../theme/app_colors.dart';

/// Navigation chrome around the tab branches (PRD §8.2).
///
/// Two shells over the same branches: a bottom bar for handhelds, and a left
/// rail for televisions (PRD Phase 3). A bottom bar is the wrong shape for a
/// remote — reaching it means walking focus down past every rail on the page,
/// and it wastes the vertical space a 16:9 screen is short of. Every screen
/// inside is shared; only the chrome differs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.live_tv_outlined, selected: Icons.live_tv, label: 'Live'),
    (icon: Icons.movie_outlined, selected: Icons.movie, label: 'Movies'),
    (
      icon: Icons.video_library_outlined,
      selected: Icons.video_library,
      label: 'Series'
    ),
    (icon: Icons.search, selected: Icons.search, label: 'Search'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  void _go(int index) => shell.goBranch(
        index,
        // Re-selecting the current tab pops it back to its root.
        initialLocation: index == shell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isTelevisionOf(ref)) return _tvShell();
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.24),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label),
        ],
      ),
    );
  }

  Widget _tvShell() {
    return Scaffold(
      body: Row(
        children: [
          // Left padding only: the content area keeps its own padding, and the
          // rail must clear the TV's overscan crop or it is physically cut off.
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 24, bottom: 24),
            child: NavigationRail(
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.accent.withValues(alpha: 0.24),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              // Labels always visible: on a 10-foot screen an icon alone is a
              // guessing game, and there is plenty of horizontal room.
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.85,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
