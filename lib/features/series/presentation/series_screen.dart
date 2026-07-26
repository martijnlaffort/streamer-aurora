import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_chips.dart';
import '../../../core/widgets/poster_card.dart';
import '../series_providers.dart';

/// Series browse (PRD §8.4) — same UX as Movies.
class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  String? _categoryId;
  SeriesSort _sort = SeriesSort.name;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(seriesCategoriesProvider);
    final series = ref.watch(seriesListProvider(_categoryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Series'),
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
      body: Column(
        children: [
          categories.when(
            data: (list) => CategoryChips(
              categories: list,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            loading: () => const SizedBox(height: 44),
            error: (e, _) => const SizedBox(height: 44),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: series.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e',
                      style: const TextStyle(color: AppColors.error))),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Nothing here yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final sorted = sortSeries(list, _sort);
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final s = sorted[i];
                    final tag = 'series-s-${s.id}';
                    return PosterCard(
                      title: s.name,
                      imageUrl: s.posterUrl,
                      heroTag: tag,
                      onTap: () =>
                          context.push('/series/${s.id}', extra: tag),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
