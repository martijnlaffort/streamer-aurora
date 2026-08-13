import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/matching/category_label.dart';
import '../../../core/rotation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/category_rails_view.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../core/matching/title_label.dart';
import '../../../domain/models/models.dart';
import '../../home/presentation/widgets/media_rail.dart';
import '../../movies/movies_providers.dart' show allCategoryId;
import '../series_providers.dart';

/// Series browse (PRD §8.4) — same category-first shape as Movies.
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(seriesCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Series'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.grid_view_outlined, size: 18),
            label: const Text('All'),
            onPressed: () => context.push('/series/category/$allCategoryId'),
          ),
        ],
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(seriesCategoriesProvider)),

        data: (list) => RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(rotationSeedProvider);
            ref.invalidate(seriesCategoriesProvider);
          },
          child: CategoryRailsView(
            categories: list,
            railBuilder: (context, category) =>
                _SeriesCategoryRail(category: category),
          ),
        ),
      ),
    );
  }
}

class _SeriesCategoryRail extends ConsumerWidget {
  const _SeriesCategoryRail({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rail = ref.watch(seriesCategoryRailProvider(category.id));
    return rail.when(
      loading: () => CategoryRailPlaceholder(title: category.name),
      error: (e, _) => const SizedBox.shrink(),
      data: (series) {
        if (series.isEmpty) return const SizedBox.shrink();
        return MediaRail(
          title: prettyCategoryName(category.name),
          itemCount: series.length,
          onSeeAll: () => context.push(
              '/series/category/${Uri.encodeComponent(category.id)}',
              extra: category.name),
          itemBuilder: (context, i) {
            final s = series[i];
            final tag = 'cat-${category.id}-s-${s.id}';
            return PosterCard(
              title: prettyTitle(s.name, year: s.year),
              imageUrl: s.posterUrl,
              rating: s.rating,
              heroTag: tag,
              onTap: () => context.push('/series/${s.id}', extra: tag),
            );
          },
        );
      },
    );
  }
}
