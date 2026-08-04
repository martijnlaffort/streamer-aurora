import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/paged_poster_grid.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../movies_providers.dart';

/// The full, paged grid for one movie category — or for everything when
/// [categoryId] is [allCategoryId]. Reached from a rail's "See all".
///
/// Sort lives here rather than on the rails screen: an ordering only means
/// something for a full list.
class MovieCategoryScreen extends ConsumerStatefulWidget {
  const MovieCategoryScreen({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  final String categoryId;

  /// Passed via `extra` when navigating from a rail so the title is right
  /// immediately; falls back to a lookup when deep-linked.
  final String? categoryName;

  @override
  ConsumerState<MovieCategoryScreen> createState() =>
      _MovieCategoryScreenState();
}

class _MovieCategoryScreenState extends ConsumerState<MovieCategoryScreen> {
  MovieSort _sort = MovieSort.added;

  bool get _isAll => widget.categoryId == allCategoryId;

  String _title(List<Category> categories) {
    if (_isAll) return 'All Movies';
    if (widget.categoryName != null) return widget.categoryName!;
    for (final c in categories) {
      if (c.id == widget.categoryId) return c.name;
    }
    return 'Movies';
  }

  Future<List<Movie>> _fetchPage(int offset, int limit) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return const [];
    // The unscoped grid still honours the content-language filter; a
    // category-scoped grid is already inside one category.
    final allowed = _isAll
        ? await ref.read(allowedCategoryIdsProvider(CategoryType.vod).future)
        : null;
    return ref.read(catalogRepositoryProvider).movies(
          account,
          categoryId: _isAll ? null : widget.categoryId,
          categoryIds: allowed,
          order: movieOrderFor(_sort),
          limit: limit,
          offset: offset,
        );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(vodCategoriesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(categories)),
        actions: [
          PopupMenuButton<MovieSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in MovieSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: PagedPosterGrid<Movie>(
        // Sort changes re-page from the top.
        reloadKey: (widget.categoryId, _sort),
        pageSize: moviesPageSize,
        fetchPage: _fetchPage,
        itemBuilder: (context, movie) {
          final tag = 'grid-${widget.categoryId}-m-${movie.id}';
          return PosterCard(
            title: movie.name,
            imageUrl: movie.posterUrl,
            rating: movie.rating,
            heroTag: tag,
            onTap: () => context.push('/movie/${movie.id}', extra: tag),
          );
        },
      ),
    );
  }
}
