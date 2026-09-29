import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/television.dart';
import '../theme/app_typography.dart';
import 'error_view.dart';

/// A poster grid that pulls its content one page at a time.
///
/// Extracted because this state machine was copy-pasted into MoviesScreen,
/// SeriesScreen and LiveScreen. It exists at all because a large catalogue
/// (150k titles) must never be held in memory: the grid asks for [pageSize]
/// rows at a time and appends as the user nears the bottom.
class PagedPosterGrid<T> extends StatefulWidget {
  const PagedPosterGrid({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    required this.pageSize,
    this.reloadKey,
    this.emptyLabel = 'Nothing here yet.',
  });

  /// Fetches one page. Called with the number of items already held, so the
  /// caller can pass it straight through as an offset.
  final Future<List<T>> Function(int offset, int limit) fetchPage;

  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;

  /// Change this to re-page from the top — a new category, a new sort order.
  /// Comparing it is what supersedes a page still in flight from the old query.
  final Object? reloadKey;

  final String emptyLabel;

  @override
  State<PagedPosterGrid<T>> createState() => _PagedPosterGridState<T>();
}

class _PagedPosterGridState<T> extends State<PagedPosterGrid<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  bool _loading = false;
  bool _atEnd = false;
  Object? _error;

  /// Bumped whenever the query changes, so a page still in flight from the
  /// previous one is discarded instead of appended.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(PagedPosterGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  /// Wraps the grid so its first card can be found. Never takes focus itself.
  final _gridFocus = FocusNode(
      debugLabel: 'poster-grid', canRequestFocus: false, skipTraversal: true);

  /// TV: once the first page is on screen, put the cursor on its first card —
  /// but only when nothing real holds it. A grid opened with "See all" used
  /// to start with no cursor at all, and the first press landed on the app
  /// bar's back arrow.
  void _focusFirstOnTv() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tv = ProviderScope.containerOf(context, listen: false)
              .read(isTelevisionProvider)
              .value ??
          false;
      if (!tv) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && primary is! FocusScopeNode) return;
      _gridFocus.traversalDescendants
          .where((n) =>
              n is! FocusScopeNode && n.canRequestFocus && !n.skipTraversal)
          .firstOrNull
          ?.requestFocus();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  void _reload() {
    _generation++;
    _items.clear();
    _atEnd = false;
    _error = null;
    _loading = false;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _atEnd) return;
    _loading = true;
    final gen = _generation;
    try {
      final page = await widget.fetchPage(_items.length, widget.pageSize);
      if (!mounted || gen != _generation) return;
      final first = _items.isEmpty && page.isNotEmpty;
      setState(() {
        _items.addAll(page);
        if (page.length < widget.pageSize) _atEnd = true;
      });
      if (first) _focusFirstOnTv();
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (gen == _generation) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return ErrorView(error: _error!, onRetry: _reload);
      }
      return EmptyView(
        icon: Icons.movie_filter_outlined,
        title: widget.emptyLabel,
        message: 'Nothing in this category has been downloaded yet. '
            'Pull down to refresh, or try another category.',
      );
    }
    // Cell height = the 2:3 poster at this column width, plus the caption at
    // the CURRENT text size. A fixed aspect ratio left room for a two-line
    // caption only up to about 1.16× text, so the Large size setting (or a
    // big system font) pushed every caption out of its cell.
    const maxCellWidth = 140.0, spacing = 12.0, sidePad = 16.0;
    final caption = MediaQuery.textScalerOf(context)
            .scale(AppTypography.label.fontSize ?? 12) *
        1.35 * // line height, with room to spare
        2; // the caption's maxLines
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth - sidePad * 2;
      // The same column count SliverGridDelegateWithMaxCrossAxisExtent picks.
      final columns =
          (available / (maxCellWidth + spacing)).ceil().clamp(1, 1 << 10);
      final cellWidth = (available - spacing * (columns - 1)) / columns;
      return Focus(
        focusNode: _gridFocus,
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(sidePad, 8, sidePad, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: spacing,
            mainAxisExtent: cellWidth * 1.5 + 6 + caption,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) => widget.itemBuilder(context, _items[i]),
        ),
      );
    });
  }
}
