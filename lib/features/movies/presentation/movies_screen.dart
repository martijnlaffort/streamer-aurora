import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/matching/category_label.dart';
import '../../../core/rotation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shell_actions.dart';
import '../../../core/widgets/category_rails_view.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../core/matching/title_label.dart';
import '../../../data/providers.dart';
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
          ShellActions(extra: [
            // Labelled, not just an icon: a bare grid glyph gives no clue that
            // it means "browse everything", and it was unreadable to a screen
            // reader as well as cryptic to a sighted user.
            TextButton.icon(
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: const Text('All'),
              onPressed: () => context.push('/movies/category/$allCategoryId'),
            ),
          ]),
        ],
      ),
      body: categories.when(
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(vodCategoriesProvider)),

        data: (list) => RefreshIndicator(
          color: AppColors.accent,
          // Users learn pull-to-refresh on Home and then try it everywhere;
          // a tab that ignores the gesture reads as broken.
          onRefresh: () async {
            ref.invalidate(rotationSeedProvider);
            ref.invalidate(vodCategoriesProvider);
          },
          child: CategoryRailsView(
            categories: list,
            railBuilder: (context, category) =>
                MovieCategoryRail(category: category),
          ),
        ),
      ),
    );
  }
}

class MovieCategoryRail extends ConsumerWidget {
  const MovieCategoryRail({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rail = ref.watch(movieCategoryRailProvider(category.id));
    // Read the VALUE rather than switching on the state. `AsyncValue` keeps the
    // last data through both a reload and an error, and rendering from it means
    // a rail that has once loaded can never blank again: an error used to
    // collapse the row to nothing, so a transient failure across several rails
    // emptied the screen and then refilled it a moment later.
    final movies = rail.value;
    if (movies == null) {
      return CategoryRailPlaceholder(title: prettyCategoryName(category.name));
    }
    // Genuinely empty category — hide it rather than leave a bald heading.
    if (movies.isEmpty) return const SizedBox.shrink();
    return MediaRail(
          title: prettyCategoryName(category.name),
          itemCount: movies.length,
          onSeeAll: () => context.push(
              '/movies/category/${Uri.encodeComponent(category.id)}',
              extra: category.name),
          itemBuilder: (context, i) {
            final movie = movies[i];
            final tag = 'cat-${category.id}-m-${movie.id}';
            return PosterCard(
              title: prettyTitle(movie.name, year: movie.year),
              imageUrl: movie.posterUrl,
              artwork: ArtworkQuery(
                  name: prettyTitle(movie.name, year: movie.year),
                  year: movie.year,
                  isSeries: false),
              rating: movie.rating,
              heroTag: tag,
              onTap: () => context.push('/movie/${movie.id}', extra: tag),
            );
          },
    );
  }
}
