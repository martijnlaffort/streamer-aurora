import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_chips.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../movies_providers.dart';

/// Movies browse (PRD §8.3): grid, category filter, sort. Paged — the grid
/// pulls the catalog a page at a time instead of loading all of it into memory,
/// so a large catalog can't push the app past the OS memory limit.
class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  String? _categoryId;
  MovieSort _sort = MovieSort.added;
  final _scroll = ScrollController();

  final List<Movie> _items = [];
  bool _loading = false;
  bool _atEnd = false;
  Object? _error;

  /// Bumped whenever the category/sort/filter changes, so a page still in
  /// flight from the previous query is discarded instead of appended.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
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
      final account = await ref.read(activeAccountProvider.future);
      if (account == null) {
        if (mounted && gen == _generation) setState(() => _atEnd = true);
        return;
      }
      final allowed = _categoryId == null
          ? await ref.read(allowedCategoryIdsProvider(CategoryType.vod).future)
          : null;
      if (gen != _generation) return; // superseded during the awaits above
      final page = await ref.read(catalogRepositoryProvider).movies(
            account,
            categoryId: _categoryId,
            categoryIds: allowed,
            order: movieOrderFor(_sort),
            limit: moviesPageSize,
            offset: _items.length,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page);
        if (page.length < moviesPageSize) _atEnd = true;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (gen == _generation) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-page from the top when the account or content-language filter changes.
    ref.listen(activeAccountProvider, (_, _) => _reload());
    ref.listen(allowedCategoryIdsProvider(CategoryType.vod), (_, _) => _reload());
    final categories = ref.watch(vodCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          PopupMenuButton<MovieSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (sort) {
              setState(() => _sort = sort);
              _reload();
            },
            itemBuilder: (context) => [
              for (final sort in MovieSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          categories.when(
            data: (list) => CategoryChips(
              categories: list,
              selectedId: _categoryId,
              onSelected: (id) {
                setState(() => _categoryId = id);
                _reload();
              },
            ),
            loading: () => const SizedBox(height: 44),
            error: (e, _) => const SizedBox(height: 44),
          ),
          const SizedBox(height: 4),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  Widget _grid() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
            child: Text('$_error',
                style: const TextStyle(color: AppColors.error)));
      }
      return const Center(
        child: Text('Nothing here yet.',
            style: TextStyle(color: AppColors.textSecondary)),
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
      itemBuilder: (context, i) {
        final movie = _items[i];
        final tag = 'movies-m-${movie.id}';
        return PosterCard(
          title: movie.name,
          imageUrl: movie.posterUrl,
          heroTag: tag,
          onTap: () => context.push('/movie/${movie.id}', extra: tag),
        );
      },
    );
  }
}
