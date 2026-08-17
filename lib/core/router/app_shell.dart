import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get shell => widget.shell;

  /// Separate scopes for the rail and the page, so focus can be moved between
  /// them explicitly.
  ///
  /// This is the part that made the rail unreachable on a real Streamer.
  /// go_router puts each branch inside its own Navigator, and a Navigator
  /// carries a FocusScope; Flutter's directional traversal does not cross a
  /// scope boundary. So pressing LEFT from the page could never find the rail
  /// no matter how focusable the rail was — the traversal never looked outside
  /// the branch. Left and Right are therefore handled here and hand focus over
  /// deliberately rather than hoping traversal finds its way.
  final _contentFocus = FocusScopeNode(debugLabel: 'tv-content');

  /// One node per rail item. Focus is handed to a *specific* item rather than
  /// to a scope: requesting focus on a FocusScopeNode focuses the scope itself
  /// and leaves every widget inside it unfocused, which looks exactly like the
  /// key press having done nothing.
  late final List<FocusNode> _railItemFocus = [
    for (final d in _destinations)
      FocusNode(debugLabel: 'rail-${d.label}'),
  ];

  bool get _railHasFocus => _railItemFocus.any((n) => n.hasFocus);

  @override
  void dispose() {
    _contentFocus.dispose();
    for (final n in _railItemFocus) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && !_railHasFocus) {
      // Land on the tab you are already looking at, not the top of the list.
      _railItemFocus[shell.currentIndex].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && _railHasFocus) {
      _contentFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

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
  Widget build(BuildContext context) {
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
      body: Focus(
        onKeyEvent: _onKey,
        // Not focusable itself — it only watches keys bubbling up from whatever
        // currently holds focus, so it can hand focus across the scope
        // boundary.
        canRequestFocus: false,
        child: Row(
          children: [
            // Left padding only: the content area keeps its own padding, and
            // the rail must clear the TV's overscan crop or it is physically
            // cut off.
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 24, bottom: 24),
              child: _TvRail(
                destinations: _destinations,
                selectedIndex: shell.currentIndex,
                onSelected: _go,
                itemFocus: _railItemFocus,
              ),
            ),
            Expanded(
              child: FocusScope(node: _contentFocus, child: shell),
            ),
          ],
        ),
      ),
    );
  }
}

/// The television navigation rail.
///
/// Hand-built rather than Material's [NavigationRail] because that widget's
/// destinations do not take D-pad focus: on a real Streamer the rail rendered
/// perfectly and was completely unreachable — pressing LEFT moved focus to the
/// root Android view (the whole screen outlined) instead of into the rail, so
/// Settings, and therefore pairing, could not be opened at all.
///
/// InkWell is the fix, for the same reason it was on the poster cards: a D-pad
/// OK press arrives as an ActivateIntent, which only widgets registering an
/// Actions handler respond to.
class _TvRail extends StatelessWidget {
  const _TvRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.itemFocus,
  });

  final List<({IconData icon, IconData selected, String label})> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FocusNode> itemFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          for (final (i, d) in destinations.indexed)
            _TvRailItem(
              icon: i == selectedIndex ? d.selected : d.icon,
              label: d.label,
              selected: i == selectedIndex,
              focusNode: itemFocus[i],
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _TvRailItem extends StatefulWidget {
  const _TvRailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_TvRailItem> createState() => _TvRailItemState();
}

class _TvRailItemState extends State<_TvRailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Focus has to be obvious from across a room, so it gets a filled
    // background and a ring rather than the subtle tint a phone can rely on.
    final background = _focused
        ? AppColors.accent
        : widget.selected
            ? AppColors.accent.withValues(alpha: 0.24)
            : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(12),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: AppColors.focusRing, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Icon(widget.icon,
                  size: 24,
                  color: _focused ? Colors.black : AppColors.textPrimary),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _focused ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
