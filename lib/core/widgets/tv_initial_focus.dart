import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/television.dart';

/// On a television, puts the cursor on the first control inside [child] once
/// it has built — but only when nothing real holds it already.
///
/// A pushed screen starts with its route's scope focused and nothing in it, so
/// the remote had no visible cursor and the first press was spent finding one
/// (often landing on the app bar's back arrow). Wrapping the page's list in
/// this is enough. Does nothing on phones, and never takes focus itself.
class TvInitialFocus extends ConsumerStatefulWidget {
  const TvInitialFocus({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TvInitialFocus> createState() => _TvInitialFocusState();
}

class _TvInitialFocusState extends ConsumerState<TvInitialFocus> {
  final _region = FocusNode(
      debugLabel: 'tv-initial-focus',
      canRequestFocus: false,
      skipTraversal: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  void _seed() {
    if (!mounted || !(ref.read(isTelevisionProvider).value ?? false)) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode) return;
    _region.traversalDescendants
        .where((n) =>
            n is! FocusScopeNode && n.canRequestFocus && !n.skipTraversal)
        .firstOrNull
        ?.requestFocus();
  }

  @override
  void dispose() {
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _region, child: widget.child);
}
