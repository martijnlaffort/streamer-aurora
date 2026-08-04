import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_rails_view.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../domain/models/models.dart';
import '../../home/presentation/widgets/media_rail.dart';
import '../movies_providers.dart';

/// Movies browse (PRD §8.3), category-first: one rail per category with
/// "See all" into the full paged grid.
///
/// This replaced a flat grid of the entire catalogue behind a horizontal chip
/// strip. With hundreds of categories that strip was unusable as a filter, and
/// the unscoped grid is the weakest view in the app — it is cache-only, because
/// 150k titles cannot be refreshed on demand. Choosing a category is now the
/// primary act, and it costs exactly one request.
class MoviesScreen extends ConsumerWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(vodCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'All movies',
            onPressed: () => context.push('/movies/category/$allCategoryId'),
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
              _MovieCategoryRail(category: category),
        ),
      ),
    );
  }
}

class _MovieCategoryRail extends ConsumerWidget {
  const _MovieCategoryRail({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rail = ref.watch(movieCategoryRailProvider(category.id));
    return rail.when(
      loading: () => CategoryRailPlaceholder(title: category.name),
      // A rail that cannot load is not worth a row of error text among dozens
      // of working ones.
      error: (e, _) => const SizedBox.shrink(),
      data: (movies) {
        // Genuinely empty category — hide it rather than leave a bald heading.
        if (movies.isEmpty) return const SizedBox.shrink();
        return MediaRail(
          title: category.name,
          itemCount: movies.length,
          onSeeAll: () => context.push(
              '/movies/category/${Uri.encodeComponent(category.id)}',
              extra: category.name),
          itemBuilder: (context, i) {
            final movie = movies[i];
            final tag = 'cat-${category.id}-m-${movie.id}';
            return PosterCard(
              title: movie.name,
              imageUrl: movie.posterUrl,
              rating: movie.rating,
              heroTag: tag,
              onTap: () => context.push('/movie/${movie.id}', extra: tag),
            );
          },
        );
      },
    );
  }
}
