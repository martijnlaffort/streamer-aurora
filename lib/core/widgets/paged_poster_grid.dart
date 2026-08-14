import 'package:flutter/material.dart';

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
    super.dispose();
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
      setState(() {
        _items.addAll(page);
        if (page.length < widget.pageSize) _atEnd = true;
      });
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
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.54,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => widget.itemBuilder(context, _items[i]),
    );
  }
}
