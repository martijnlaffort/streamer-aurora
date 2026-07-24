import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/models.dart';

/// Everything the Home screen renders, resolved in one pass from the cached
/// catalog (reads are DB-backed; the repository handles TTL refreshes).
class HomeData {
  const HomeData({
    required this.hero,
    required this.recentlyAdded,
    required this.continueWatching,
    required this.categoryRails,
  });

  final Movie? hero;
  final List<Movie> recentlyAdded;

  /// Progress entries resolved to their movies (episode resume joins in 1.3+).
  final List<(WatchProgress, Movie)> continueWatching;
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

  // Hero: newest item, enriched with its backdrop when the panel is up
  // (falls back to the cached row offline).
  Movie? hero = recentlyAdded.firstOrNull;
  if (hero != null && hero.backdropUrl == null) {
    try {
      hero = await catalog.movieDetail(account, hero.id);
    } on Exception {
      // Cached row is fine — hero just uses the poster.
    }
  }

  // Continue Watching (PRD §8.9): resolve movie keys against the cache.
  final progress =
      await ref.watch(watchProgressRepositoryProvider).continueWatching();
  final continueWatching = <(WatchProgress, Movie)>[];
  for (final p in progress) {
    final key = parseContentKey(p.contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type != StreamType.movie.name) continue;
    final movie = await catalog.movieById(account, key.id);
    if (movie != null) continueWatching.add((p, movie));
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
    hero: hero,
    recentlyAdded: recentlyAdded,
    continueWatching: continueWatching,
    categoryRails: rails,
  );
});
