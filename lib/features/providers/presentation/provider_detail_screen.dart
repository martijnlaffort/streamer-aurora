import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/matching/title_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart' show ArtworkQuery;
import '../../../domain/models/models.dart';
import '../../home/presentation/widgets/media_rail.dart';
import '../../movies/presentation/movies_screen.dart' show MovieCategoryRail;
import '../../series/presentation/series_screen.dart' show SeriesCategoryRail;
import '../providers_providers.dart';

/// One streaming service: rails picked across all of its groups first, then
/// its film groups and series groups.
///
/// Reuses the Movies and Series rails for the groups rather than
/// reimplementing them — they carry the dwell debounce, the cache-first read
/// and the "never blank once loaded" behaviour, and a second copy of that
/// would drift.
class ProviderDetailScreen extends ConsumerWidget {
  const ProviderDetailScreen({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(providerShelfProvider(brandId));

    return Scaffold(
      appBar: AppBar(title: Text(shelf.value?.brand.name ?? 'Service')),
      body: shelf.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(providerShelfProvider(brandId))),
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
          // Films then series, each section headed so the two id spaces stay
          // visibly separate — a category called "Kids" can exist in both and
          // they are not the same thing. Rows are addressed by POSITION: film
          // and series ids are separate spaces, and looking a row up by id
          // alone rendered a series group that shared an id with a film group
          // as films.
          final rows = <({Category category, bool isMovie})>[
            for (final c in data.movieCategories) (category: c, isMovie: true),
            for (final c in data.seriesCategories) (category: c, isMovie: false),
          ];
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: _Highlights(brandId: brandId, name: data.brand.name)),
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final rail = row.isMovie
                      ? MovieCategoryRail(category: row.category)
                      : SeriesCategoryRail(category: row.category);
                  final startsSection = i == 0 || rows[i - 1].isMovie != row.isMovie;
                  if (!startsSection) return rail;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                            row.isMovie ? 'Film groups' : 'Series groups',
                            style: AppTypography.title),
                      ),
                      rail,
                    ],
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

/// The rails a service's page opens with; see [providerHighlightsProvider].
class _Highlights extends ConsumerWidget {
  const _Highlights({required this.brandId, required this.name});

  final String brandId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(providerHighlightsProvider(brandId));
    final data = highlights.value;
    if (data == null) {
      return highlights.isLoading
          ? CategoryRailPlaceholder(title: 'New on $name')
          : const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.newMovies.isNotEmpty)
          _movieRail(context, 'New on $name', 'new', data.newMovies),
        if (data.topMovies.length >= 5)
          _movieRail(context, 'Top rated films', 'top', data.topMovies),
        if (data.topSeries.length >= 5)
          MediaRail(
            title: 'Top rated series',
            itemCount: data.topSeries.length,
            itemBuilder: (context, i) {
              final s = data.topSeries[i];
              final tag = 'svc-$brandId-top-s-${s.id}';
              return PosterCard(
                title: prettyTitle(s.name, year: s.year),
                imageUrl: s.posterUrl,
                artwork: ArtworkQuery(
                    name: prettyTitle(s.name, year: s.year),
                    year: s.year,
                    isSeries: true),
                rating: s.rating,
                heroTag: tag,
                onTap: () => context.push('/series/${s.id}', extra: tag),
              );
            },
          ),
      ],
    );
  }

  Widget _movieRail(
      BuildContext context, String title, String key, List<Movie> movies) {
    return MediaRail(
      title: title,
      itemCount: movies.length,
      itemBuilder: (context, i) {
        final movie = movies[i];
        final tag = 'svc-$brandId-$key-m-${movie.id}';
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
