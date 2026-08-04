import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
import '../../data/repositories/discovery_repository.dart';
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
  });

  /// Rotating featured hero candidates (newest first).
  final List<Movie> heroes;
  final List<Movie> recentlyAdded;

  /// Continue Watching (PRD §8.9): movies and series, most-recent first.
  final List<ContinueEntry> continueWatching;
}

const _railLength = 15;

/// The discovery rails (PRD §8.2): externally-ranked lists filtered to what the
/// playlist carries. Kept in their OWN provider, deliberately separate from
/// [homeDataProvider]: they touch the network and walk the catalogue, and Home
/// must never wait on either — that is the mistake the hero enrichment made.
/// Home renders its cached rails first and these appear underneath when ready.
final discoveryRailsProvider =
    FutureProvider<List<DiscoveryRail<Object>>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final repo = ref.watch(discoveryRepositoryProvider);
  // Rebuild when the key or region changes so new rails appear immediately.
  ref.watch(preferencesProvider);
  await repo.refresh(account);

  final rails = <DiscoveryRail<Object>>[];
  for (final list in DiscoveryRepository.lists) {
    final items = list.kind == DiscoveryKind.movie
        ? await repo.railMovies(account, list.id)
        : await repo.railSeries(account, list.id);
    // A rail with one or two hits looks broken; below this the playlist simply
    // does not carry enough of that list to be worth a row.
    if (items.length >= 3) {
      rails.add(DiscoveryRail<Object>(label: list.label, items: items));
    }
  }
  return rails;
});

/// The backdrop for one featured hero, resolved lazily off Home's critical
/// path. Home paints from the cache immediately (the hero falls back to the
/// poster) and swaps in the wider backdrop if and when this lands; a panel that
/// is slow or down just means the poster stays. Not autoDispose: the hero
/// rotates every few seconds and returns, and refetching each time it comes
/// back around would be pointless traffic.
final heroBackdropProvider =
    FutureProvider.family<String?, String>((ref, movieId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  try {
    final detail = await ref
        .watch(catalogRepositoryProvider)
        .movieDetail(account, movieId);
    return detail.backdropUrl;
  } on Exception {
    return null; // Cosmetic only — never surface this as an error.
  }
});

final homeDataProvider = FutureProvider<HomeData?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final catalog = ref.watch(catalogRepositoryProvider);

  // Content-language filter (PRD §8.3): everything on Home is restricted to
  // categories whose detected language is enabled. Category IDs are resolved
  // once here; `null` sets mean the filter is off (show all).
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  final Set<String>? allowedVod = enabled == null
      ? null
      : (await catalog.categories(account, CategoryType.vod))
          .where((c) => enabled.contains(detectContentLanguage(c.name).code))
          .map((c) => c.id)
          .toSet();
  // Home's rails are sorted and limited in SQL (see CatalogRepository) — the
  // whole catalog is never pulled into memory, which is what let large
  // playlists push a sideloaded build past iOS's memory limit. A `null`
  // allowed-set means the content-language filter is off (show all).

  // Recently added drives the hero + the one rail.
  final recentlyAdded = await catalog.recentMovies(account,
      limit: _railLength, categoryIds: allowedVod);

  // Featured heroes: the newest few, straight from the cache. Backdrops are
  // NOT resolved here — see [heroBackdropProvider]. This used to await
  // `movieDetail` per hero, i.e. up to five sequential `get_vod_info`
  // round-trips before Home rendered anything; on a real panel that is seconds
  // of spinner for a cosmetic upgrade the hero already falls back from (it
  // shows the poster when there is no backdrop).
  final heroes = recentlyAdded.take(5).toList();

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

  // Per-category rails used to live here. They moved to the Movies and Series
  // tabs, which are now category-first — Home linking to six arbitrary
  // categories was both redundant and the thing that made every cold start
  // refresh six categories before it could paint.
  return HomeData(
    heroes: heroes,
    recentlyAdded: recentlyAdded,
    continueWatching: continueWatching,
  );
});
