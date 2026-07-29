import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.categoryRails,
  });

  /// Rotating featured hero candidates (newest first).
  final List<Movie> heroes;
  final List<Movie> recentlyAdded;

  /// Continue Watching (PRD §8.9): movies and series, most-recent first.
  final List<ContinueEntry> continueWatching;
  final List<(Category, List<Movie>)> categoryRails;
}

const _railLength = 15;
const _maxCategoryRails = 6;

final homeDataProvider = FutureProvider<HomeData?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final catalog = ref.watch(catalogRepositoryProvider);

  // Recently added drives the hero + first rail.
  final all = await catalog.movies(account);
  final recent = [...all]..sort((a, b) {
      final at = a.addedAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.addedAt?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
  final recentlyAdded = recent.take(_railLength).toList();

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
  final categories = await catalog.categories(account, CategoryType.vod);
  final rails = <(Category, List<Movie>)>[];
  for (final category in categories.take(_maxCategoryRails)) {
    final movies =
        await catalog.movies(account, categoryId: category.id, limit: _railLength);
    if (movies.isNotEmpty) rails.add((category, movies));
  }

  return HomeData(
    heroes: heroes,
    recentlyAdded: recentlyAdded,
    continueWatching: continueWatching,
    categoryRails: rails,
  );
});
