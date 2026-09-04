import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/category_rails_view.dart';
import '../../../domain/models/models.dart';
import '../../movies/presentation/movies_screen.dart' show MovieCategoryRail;
import '../../series/presentation/series_screen.dart' show SeriesCategoryRail;
import '../providers_providers.dart';

/// One streaming service: its film groups and series groups, as rails.
///
/// Reuses the Movies and Series rails rather than reimplementing them — they
/// carry the dwell debounce, the cache-first read and the "never blank once
/// loaded" behaviour, and a second copy of that would drift.
class ProviderDetailScreen extends ConsumerWidget {
  const ProviderDetailScreen({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(providerShelfProvider(brandId));

    return Scaffold(
      appBar: AppBar(title: Text(shelf.value?.brand.name ?? 'Provider')),
      body: shelf.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.error))),
        data: (data) {
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This playlist no longer carries that service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          // One list, films then series, each section headed so the two id
          // spaces stay visibly separate — a category called "Kids" can exist
          // in both and they are not the same thing.
          final rows = <({Category category, bool isMovie})>[
            for (final c in data.movieCategories) (category: c, isMovie: true),
            for (final c in data.seriesCategories) (category: c, isMovie: false),
          ];
          return CategoryRailsView(
            categories: [for (final r in rows) r.category],
            railBuilder: (context, category) {
              final row = rows.firstWhere((r) => r.category.id == category.id);
              final first = rows.indexOf(row) == 0;
              final firstSeries = !row.isMovie &&
                  data.seriesCategories.isNotEmpty &&
                  data.seriesCategories.first.id == category.id;
              final rail = row.isMovie
                  ? MovieCategoryRail(category: category)
                  : SeriesCategoryRail(category: category);
              if (!first && !firstSeries) return rail;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(row.isMovie ? 'Films' : 'Series',
                        style: AppTypography.title),
                  ),
                  rail,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
