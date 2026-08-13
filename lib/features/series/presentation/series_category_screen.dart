import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/matching/category_label.dart';
import '../../../core/widgets/paged_poster_grid.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../core/matching/title_label.dart';
import '../../../domain/models/models.dart';
import '../../movies/movies_providers.dart' show allCategoryId;
import '../series_providers.dart';

/// The full, paged grid for one series category — or everything when
/// [categoryId] is [allCategoryId]. Mirrors MovieCategoryScreen.
class SeriesCategoryScreen extends ConsumerStatefulWidget {
  const SeriesCategoryScreen({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  final String categoryId;
  final String? categoryName;

  @override
  ConsumerState<SeriesCategoryScreen> createState() =>
      _SeriesCategoryScreenState();
}

class _SeriesCategoryScreenState extends ConsumerState<SeriesCategoryScreen> {
  SeriesSort _sort = SeriesSort.name;

  bool get _isAll => widget.categoryId == allCategoryId;

  String _title(List<Category> categories) {
    if (_isAll) return 'All Series';
    if (widget.categoryName != null) {
      return prettyCategoryName(widget.categoryName!);
    }
    for (final c in categories) {
      if (c.id == widget.categoryId) return prettyCategoryName(c.name);
    }
    return 'Series';
  }

  Future<List<Series>> _fetchPage(int offset, int limit) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return const [];
    final allowed = _isAll
        ? await ref.read(allowedCategoryIdsProvider(CategoryType.series).future)
        : null;
    return ref.read(catalogRepositoryProvider).series(
          account,
          categoryId: _isAll ? null : widget.categoryId,
          categoryIds: allowed,
          order: seriesOrderFor(_sort),
          limit: limit,
          offset: offset,
        );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(seriesCategoriesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(categories)),
        actions: [
          PopupMenuButton<SeriesSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in SeriesSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: PagedPosterGrid<Series>(
        reloadKey: (widget.categoryId, _sort),
        pageSize: seriesPageSize,
        fetchPage: _fetchPage,
        itemBuilder: (context, s) {
          final tag = 'grid-${widget.categoryId}-s-${s.id}';
          return PosterCard(
            title: prettyTitle(s.name, year: s.year),
            imageUrl: s.posterUrl,
            rating: s.rating,
            heroTag: tag,
            onTap: () => context.push('/series/${s.id}', extra: tag),
          );
        },
      ),
    );
  }
}
