import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_rails_view.dart';
import '../../../core/widgets/poster_card.dart';
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
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'All series',
            onPressed: () => context.push('/series/category/$allCategoryId'),
          ),
        ],
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
          ),
        ),
        data: (list) => CategoryRailsView(
          categories: list,
          railBuilder: (context, category) =>
              _SeriesCategoryRail(category: category),
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
          title: category.name,
          itemCount: series.length,
          onSeeAll: () => context.push(
              '/series/category/${Uri.encodeComponent(category.id)}',
              extra: category.name),
          itemBuilder: (context, i) {
            final s = series[i];
            final tag = 'cat-${category.id}-s-${s.id}';
            return PosterCard(
              title: s.name,
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
