import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';

/// One Continue Watching card — a movie, or a series (represented by its
/// most-recent in-progress episode).
class ContinueEntry {
  const ContinueEntry({
    required this.progress,
    required this.title,
    required this.route,
    this.subtitle,
    this.imageUrl,
  });

  final WatchProgress progress;
  final String title;

  /// e.g. "S1 · E2" for an episode; null for a movie.
  final String? subtitle;
  final String? imageUrl;

  /// Where tapping the card goes ('/movie/:id' or '/series/:id').
  final String route;
}

/// Everything the Home screen renders, resolved in one pass from the cached
/// catalog (reads are DB-backed; the repository handles TTL refreshes).
class HomeData {
  const HomeData({
    required this.heroes,
    required this.recentlyAdded,
    required this.continueWatching,
    required this.popularMovies,
    required this.popularSeries,
    required this.categoryRails,
  });

  /// Rotating featured hero candidates (newest first).
  final List<Movie> heroes;
  final List<Movie> recentlyAdded;

  /// Continue Watching (PRD §8.9): movies and series, most-recent first.
  final List<ContinueEntry> continueWatching;

  /// "Popular" = highest-rated (IPTV has no real trending signal, so the
  /// panel's rating is the proxy). Empty when the panel provides no ratings.
  final List<Movie> popularMovies;
  final List<Series> popularSeries;
  final List<(Category, List<Movie>)> categoryRails;
}

const _railLength = 15;
const _maxCategoryRails = 6;

final homeDataProvider = FutureProvider<HomeData?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final catalog = ref.watch(catalogRepositoryProvider);

  // Content-language filter (PRD §8.3): everything on Home is restricted to
  // categories whose detected language is enabled. Category IDs are resolved
  // once here; `null` sets mean the filter is off (show all).
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  final vodCategories = await catalog.categories(account, CategoryType.vod);
  final seriesCategories =
      await catalog.categories(account, CategoryType.series);
  final Set<String>? allowedVod = enabled == null
      ? null
      : vodCategories
          .where((c) => enabled.contains(detectContentLanguage(c.name).code))
          .map((c) => c.id)
          .toSet();
  final Set<String>? allowedSeries = enabled == null
      ? null
      : seriesCategories
          .where((c) => enabled.contains(detectContentLanguage(c.name).code))
          .map((c) => c.id)
          .toSet();
  // Home's rails are sorted and limited in SQL (see CatalogRepository) — the
  // whole catalog is never pulled into memory, which is what let large
  // playlists push a sideloaded build past iOS's memory limit. A `null`
  // allowed-set means the content-language filter is off (show all).

  // Recently added drives the hero + first rail.
  final recentlyAdded = await catalog.recentMovies(account,
      limit: _railLength, categoryIds: allowedVod);

  // "Popular" = top-rated (no true trending signal exists for IPTV; the
  // panel's rating is the honest proxy). Hidden entirely when unrated.
  final popularMovies = await catalog.topRatedMovies(account,
      limit: _railLength, categoryIds: allowedVod);
  final popularSeries = await catalog.topRatedSeries(account,
      limit: _railLength, categoryIds: allowedSeries);

  // Featured heroes: the newest few, enriched with backdrops when the panel
  // is up (cached rows are fine offline) — the Home hero rotates through them.
  final heroes = <Movie>[];
  for (final candidate in recentlyAdded.take(5)) {
    if (candidate.backdropUrl != null) {
      heroes.add(candidate);
      continue;
    }
    try {
      heroes.add(await catalog.movieDetail(account, candidate.id));
    } on Exception {
      heroes.add(candidate);
    }
  }

  // Continue Watching (PRD §8.9): movies play directly; episodes resolve back
  // to their series (one card per series — the most-recent episode, since the
  // list is already updatedAt-desc).
  final progress =
      await ref.watch(watchProgressRepositoryProvider).continueWatching();
  final continueWatching = <ContinueEntry>[];
  final seenSeries = <String>{};
  for (final p in progress) {
    final key = parseContentKey(p.contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type == StreamType.movie.name) {
      final movie = await catalog.movieById(account, key.id);
      if (movie != null) {
        continueWatching.add(ContinueEntry(
          progress: p,
          title: movie.name,
          imageUrl: movie.backdropUrl ?? movie.posterUrl,
          route: '/movie/${movie.id}',
        ));
      }
    } else if (key.type == StreamType.episode.name) {
      final episode = await catalog.episodeById(account, key.id);
      if (episode == null || !seenSeries.add(episode.seriesId)) continue;
      final series = await catalog.seriesById(account, episode.seriesId);
      if (series == null) continue;
      continueWatching.add(ContinueEntry(
        progress: p,
        title: series.name,
        subtitle: 'S${episode.seasonNumber} · E${episode.episodeNumber}',
        imageUrl: series.backdropUrl ?? series.posterUrl,
        route: '/series/${series.id}',
      ));
    }
  }

  // Per-category rails via paged reads — no full-catalog loads per rail.
  // Reuses the language-filtered VOD categories resolved above.
  final railCategories = allowedVod == null
      ? vodCategories
      : vodCategories.where((c) => allowedVod.contains(c.id)).toList();
  final rails = <(Category, List<Movie>)>[];
  for (final category in railCategories.take(_maxCategoryRails)) {
    final movies =
        await catalog.movies(account, categoryId: category.id, limit: _railLength);
    if (movies.isNotEmpty) rails.add((category, movies));
  }

  return HomeData(
    heroes: heroes,
    recentlyAdded: recentlyAdded,
    continueWatching: continueWatching,
    popularMovies: popularMovies,
    popularSeries: popularSeries,
    categoryRails: rails,
  );
});
