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

  /// Collapsed the rail shows icons only and the page keeps the screen; focused
  /// it widens over the page to reveal labels. This is the shape Netflix and
  /// HBO both use, and it is a deliberate trade: a permanently open rail either
  /// eats a fifth of a 16:9 screen or stays too narrow to read from a sofa —
  /// which is exactly what the first version did.
  static const _collapsedWidth = 96.0;
  static const _expandedWidth = 300.0;

  @override
  void initState() {
    super.initState();
    // The rail expands on focus, and focus changes do not rebuild by
    // themselves.
    for (final node in _railItemFocus) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
    // Put the cursor somewhere real as soon as the first tab has built, so the
    // app opens with something visibly highlighted instead of waiting for a
    // press to reveal where focus is. Two frames: one for the shell, one for the
    // branch's own content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !isTelevisionOf(ref)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_railHasFocus) _enterContent();
      });
    });
  }

  @override
  void dispose() {
    _contentFocus.dispose();
    for (final n in _railItemFocus) {
      n.dispose();
    }
    super.dispose();
  }

  /// Moves focus onto a real widget inside the page.
  ///
  /// [FocusScopeNode.requestFocus] stops at the scope: go_router wraps every
  /// branch in its own Navigator (its own scope), so requesting focus on the
  /// content scope left the actual poster cards unfocused — the page scrolled
  /// under the D-pad but nothing ever highlighted, and there was no way to tell
  /// what was selected. Focusing a concrete descendant crosses that boundary.
  ///
  /// A scope remembers where focus last sat, so re-entering the page returns
  /// you to the card you left rather than jumping back to the top.
  void _enterContent() {
    final scope = _contentFocus;
    if (scope.focusedChild != null) {
      scope.requestFocus(); // Restores the last focused card.
      return;
    }
    final first = scope.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal)
        .firstOrNull;
    (first ?? scope).requestFocus();
  }

  void _enterRail() => _railItemFocus[shell.currentIndex].requestFocus();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // The shell node holds focus only in the brief limbo before anything real
    // does — on first launch, or just after a tab switch. Any directional
    // press from there should land on actual content rather than do nothing,
    // which was the whole reason the remote felt dead on the Home screen.
    final inLimbo = node.hasPrimaryFocus;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_railHasFocus) return KeyEventResult.handled; // already leftmost
      if (inLimbo) {
        _enterRail();
        return KeyEventResult.handled;
      }
      // In content: move left through the row first, and only fall through to
      // the rail when there is nothing further left — so LEFT scrubs a poster
      // rail exactly as expected and reaches the nav only at the edge.
      //
      // The move MUST be asked of the focused card itself, not of
      // _contentFocus. go_router nests each branch in its own Navigator scope,
      // so _contentFocus's focused child is that whole nested scope — its rect
      // is the entire page, "is anything to my left?" always answered no, and
      // the rail opened on every single LEFT press. The primary focus is the
      // real card, sitting in the branch scope beside its neighbours, so a left
      // move finds the previous card and only fails at the true edge of the row.
      final moved = FocusManager.instance.primaryFocus
              ?.focusInDirection(TraversalDirection.left) ??
          false;
      if (!moved) _enterRail();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_railHasFocus || inLimbo) {
        _enterContent();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // content traversal moves between cards
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (inLimbo) {
        _enterContent();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // traversal within the rail or the page
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
    (
      icon: Icons.apps_outlined,
      selected: Icons.apps,
      label: 'Providers'
    ),
    (icon: Icons.search, selected: Icons.search, label: 'Search'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  /// Which branches the PHONE's bottom bar carries.
  ///
  /// Search and Settings are deliberately absent: seven destinations is past
  /// what a bottom bar can hold legibly, and those two are tools rather than
  /// places — everything left in the bar is somewhere content lives. They move
  /// to the app bar (see [ShellActions]), which is also where a phone user's
  /// thumb expects a search icon.
  ///
  /// The television keeps all seven. A vertical rail has the room, and a
  /// top-right icon is a long walk with a D-pad.
  static const _phoneBarBranches = [0, 1, 2, 3, 4];

  void _go(int index) {
    shell.goBranch(
      index,
      // Re-selecting the current tab pops it back to its root.
      initialLocation: index == shell.currentIndex,
    );
    // Hand focus into the new branch once it has actually built.
    //
    // Without this the remote felt broken for one press after every tab switch:
    // the new branch's cards do not exist yet when goBranch returns, so there is
    // nothing to focus, focus stays on the shell's own node, and the next
    // direction press is spent getting into the content instead of moving
    // within it. A post-frame hand-off means the tab is live the moment it
    // appears.
    if (!isTelevisionOf(ref)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isTelevisionOf(ref)) return _tvShell();
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.24),
        // Search and Settings are branches the bar does not carry, so while one
        // of them is showing there is no bar item to light up. Fall back to the
        // first rather than leave the bar in an impossible state — the bar has
        // to stay usable, since it is the only way back to the content tabs.
        selectedIndex: _phoneBarBranches.indexOf(shell.currentIndex).clamp(0,
            _phoneBarBranches.length - 1),
        onDestinationSelected: (i) => _go(_phoneBarBranches[i]),
        destinations: [
          for (final branch in _phoneBarBranches)
            NavigationDestination(
                icon: Icon(_destinations[branch].icon),
                selectedIcon: Icon(_destinations[branch].selected),
                label: _destinations[branch].label),
        ],
      ),
    );
  }

  Widget _tvShell() {
    return Scaffold(
      body: Focus(
        onKeyEvent: _onKey,
        // Holds focus on first build so the very first D-pad press is handled
        // rather than lost to the root view (which left the remote apparently
        // dead until something happened to grab focus). skipTraversal keeps it
        // out of the traversal order once real widgets take over; autofocus
        // seeds it.
        autofocus: true,
        skipTraversal: true,
        // Overscan. Televisions crop the outer few percent of the signal, so
        // anything anchored to an edge — the rail's icons, the right-hand end of
        // every poster rail, the A-Z index — is physically off-screen on a real
        // set while looking correct in an emulator. Padding the whole stack
        // insets the rail and the content together, which is why it goes here
        // and not inside each screen.
        //
        // The player is a root-level route that covers this shell and carries
        // its own, larger inset (see _tvControls) — it is full-bleed video with
        // controls floated on top, a different problem.
        child: Padding(
          padding: tvOverscan,
          child: Stack(
            children: [
              // The page is inset by the COLLAPSED width only, so expanding the
              // rail never reflows it. Pushing the page sideways every time focus
              // touched the rail would make the whole screen twitch.
              Padding(
                padding: const EdgeInsets.only(left: _collapsedWidth),
                child: FocusScope(node: _contentFocus, child: shell),
              ),
              // Pinned to the full height explicitly. Left to size itself in a
              // Stack it takes its content's height, which on a short landscape
              // screen overflows — and Flutter reports that every single frame,
              // which was enough to hang the app outright.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _TvRail(
                  destinations: _destinations,
                  selectedIndex: shell.currentIndex,
                  onSelected: _go,
                  itemFocus: _railItemFocus,
                  expanded: _railHasFocus,
                  collapsedWidth: _collapsedWidth,
                  expandedWidth: _expandedWidth,
                ),
              ),
            ],
          ),
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
    required this.expanded,
    required this.collapsedWidth,
    required this.expandedWidth,
  });

  final List<({IconData icon, IconData selected, String label})> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FocusNode> itemFocus;
  final bool expanded;
  final double collapsedWidth;
  final double expandedWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        // A gradient rather than a panel: expanded, the rail floats over the
        // page and fades out instead of ending on a hard edge, which is what
        // stops it reading as a phone drawer bolted onto a television.
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: expanded
              ? [
                  AppColors.background,
                  AppColors.background.withValues(alpha: 0.97),
                  AppColors.background.withValues(alpha: 0.0),
                ]
              : [
                  AppColors.background.withValues(alpha: 0.85),
                  AppColors.background.withValues(alpha: 0.0),
                ],
          stops: expanded ? const [0.0, 0.62, 1.0] : const [0.0, 1.0],
        ),
      ),
      // Clear of the overscan crop, which eats the outer few percent of the
      // picture on a real set. Scrollable so the rail cannot overflow on a
      // short screen — six items at a readable size do not fit every panel,
      // and an overflow here is a hang rather than a cosmetic glitch.
      padding: const EdgeInsets.only(top: 28, bottom: 20, left: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, d) in destinations.indexed)
              _TvRailItem(
                icon: i == selectedIndex ? d.selected : d.icon,
                label: d.label,
                selected: i == selectedIndex,
                expanded: expanded,
                focusNode: itemFocus[i],
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TvRailItem extends StatefulWidget {
  const _TvRailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.focusNode,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_TvRailItem> createState() => _TvRailItemState();
}

class _TvRailItemState extends State<_TvRailItem> {
  bool _focused = false;

  /// Height of one row. Generous on purpose — a 10-foot UI wants targets you
  /// can land on without aiming.
  static const _rowHeight = 56.0;

  /// Width of the icon column, matched to the rail's collapsed width so icons
  /// do not shift sideways when the labels appear.
  static const _iconColumn = 56.0;

  @override
  Widget build(BuildContext context) {
    // Three states, and they have to be told apart instantly from a sofa:
    //   focused  — where the remote is now: solid accent, dark text
    //   selected — the tab you are on: accent text, no fill
    //   neither  — muted
    // The old version filled BOTH focused and selected, which on a real screen
    // read as two cursors at once.
    final Color foreground = _focused
        ? Colors.black
        : widget.selected
            ? AppColors.accentAlt
            : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 20),
      child: InkWell(
        onTap: widget.onTap,
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(_rowHeight / 2),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: _rowHeight,
          decoration: BoxDecoration(
            color: _focused ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(_rowHeight / 2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _iconColumn,
                child: Icon(widget.icon, size: 26, color: foreground),
              ),
              // Laid out at full width and clipped, so the label slides out
              // from behind the icon column instead of being re-wrapped
              // character by character while the rail is mid-animation.
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: 200,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: widget.expanded ? 1 : 0,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
