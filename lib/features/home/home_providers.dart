import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../core/matching/title_match.dart';
import '../../core/rotation.dart';
import '../../core/seasonal.dart';
import '../../data/providers.dart';
import '../../data/repositories/discovery_repository.dart';
import '../../core/matching/title_label.dart';
import '../../domain/models/models.dart';

/// One Continue Watching card — a movie, or a series (represented by its
/// most-recent in-progress episode).
class ContinueEntry {
  const ContinueEntry({
    required this.progress,
    required this.title,
    required this.route,
    required this.streamRef,
    this.subtitle,
    this.imageUrl,
  });

  final WatchProgress progress;
  final String title;

  /// e.g. "S1 · E2" for an episode; null for a movie.
  final String? subtitle;
  final String? imageUrl;

  /// Where the "Details" action goes ('/movie/:id' or '/series/:id').
  final String route;

  /// Everything needed to start playing without a detour via the detail page.
  /// Tapping this row should resume — two extra taps to get back into
  /// something you were half-way through is the friction the row exists to
  /// remove, and both Netflix and HBO play straight from it.
  final StreamRef streamRef;

  /// Where to resume, or null to start from the beginning (a queued next
  /// episode you have not started).
  int? get resumeFromSeconds =>
      progress.positionSeconds > 0 ? progress.positionSeconds : null;
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

/// How deep to read for a rail that rotates: the rail shows a slice of this.
const _railPool = 60;

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

  final region = ref.watch(discoveryRegionProvider);
  final seed = ref.watch(rotationSeedProvider);
  final rails = <DiscoveryRail<Object>>[];
  for (final list in DiscoveryRepository.lists) {
    // Pull a deeper pool than the rail shows so there is something to rotate
    // through — the award canon in particular is static, so without this it is
    // the same twenty films forever.
    var items = list.kind == DiscoveryKind.movie
        ? await repo.railMovies(account, list.id, limit: _railPool)
        : await repo.railSeries(account, list.id, limit: _railPool);
    // A rail with one or two hits looks broken; below this the playlist simply
    // does not carry enough of that list to be worth a row.
    if (items.length < 3) continue;
    if (list.numbered) {
      // A Top 10 must stay in rank order — the rank IS the content.
      items = items.take(10).toList();
    } else {
      items = rotatedSample(items, seed: seed, take: 20, salt: list.id);
    }
    rails.add(DiscoveryRail<Object>(
      // A rank is only meaningful if you know what it ranks — say the region.
      label: list.numbered ? 'Top 10 in $region' : list.label,
      items: items,
      numbered: list.numbered,
    ));
  }
  return rails;
});

/// The seasonal rail, or null for most of the year.
///
/// Costs one cache-only query and no network at all — the whole point of it is
/// that it is discovery with no external dependency whatsoever. Rotated like
/// the others so the same twenty horror films are not waiting every October
/// evening.
final seasonalRailProvider =
    FutureProvider<({String label, List<Movie> items})?>((ref) async {
  final season = seasonFor(DateTime.now());
  if (season == null) return null;
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;

  final allowed = await ref.watch(allowedCategoryIdsProvider(CategoryType.vod).future);
  final pool = await ref.watch(catalogRepositoryProvider).moviesByKeywords(
        account,
        genreKeywords: season.genreKeywords,
        titleKeywords: season.titleKeywords,
        categoryIds: allowed,
        limit: _railLength * 3,
      );
  if (pool.isEmpty) return null;

  final seed = ref.watch(rotationSeedProvider);
  final pages = (pool.length / _railLength).ceil().clamp(1, 3);
  final page = rotatingPage(seed: seed, pages: pages, salt: season.id);
  var items = pool.skip(page * _railLength).take(_railLength).toList();
  if (items.isEmpty) items = pool.take(_railLength).toList();
  return (label: season.label, items: items);
});

/// "My List" — favourites resolved to catalogue rows.
///
/// Netflix and HBO both give this a top-level row; Dawn Player already had the data
/// but only exposed it behind Settings, so it was effectively invisible.
///
/// Live channels are deliberately left out: a 2:3 poster rail of channel logos
/// looks broken, and they stay reachable from the Live tab and Settings →
/// Favorites.
///
/// Three key shapes are accepted. `series` keys come from the detail page's My
/// List button; `episode` keys are the older path (before a series could be
/// added directly, favouriting an episode was the only way to mark a show) and
/// still resolve to their series, de-duplicated against both.
final myListProvider = FutureProvider<List<Object>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final catalog = ref.watch(catalogRepositoryProvider);
  final favorites = await ref.watch(favoritesRepositoryProvider).all();
  final out = <Object>[];
  final seenSeries = <String>{};
  for (final (contentKey, _) in favorites) {
    final key = parseContentKey(contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type == StreamType.movie.name) {
      final movie = await catalog.movieById(account, key.id);
      if (movie != null) out.add(movie);
    } else if (key.type == seriesContentType) {
      if (!seenSeries.add(key.id)) continue;
      final series = await catalog.seriesById(account, key.id);
      if (series != null) out.add(series);
    } else if (key.type == StreamType.episode.name) {
      final episode = await catalog.episodeById(account, key.id);
      if (episode == null || !seenSeries.add(episode.seriesId)) continue;
      final series = await catalog.seriesById(account, episode.seriesId);
      if (series != null) out.add(series);
    }
  }
  return out;
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

  // Recently added drives the hero + the one rail. Read three rails' worth so
  // the rail can show a different slice each session — but page WITHIN the
  // recent set rather than shuffling it, because everything shown under
  // "Recently Added" still has to actually be recent.
  final seed = ref.watch(rotationSeedProvider);
  final recentPool = await catalog.recentMovies(account,
      limit: _railLength * 3, categoryIds: allowedVod);
  final recentPage =
      rotatingPage(seed: seed, pages: 3, salt: 'recently-added');
  var recentlyAdded =
      recentPool.skip(recentPage * _railLength).take(_railLength).toList();
  // A thin catalogue can leave the chosen page empty — fall back to the top.
  if (recentlyAdded.isEmpty) {
    recentlyAdded = recentPool.take(_railLength).toList();
  }

  // Featured heroes: the newest few, straight from the cache. Backdrops are
  // NOT resolved here — see [heroBackdropProvider]. This used to await
  // `movieDetail` per hero, i.e. up to five sequential `get_vod_info`
  // round-trips before Home rendered anything; on a real panel that is seconds
  // of spinner for a cosmetic upgrade the hero already falls back from (it
  // shows the poster when there is no backdrop).
  // Heroes come from the true newest, NOT the rotated page: the spotlight is
  // labelled "Recently Added", and putting the 40th-newest film there would be
  // a small lie. The hero already rotates through five on its own timer.
  final heroes = recentPool.take(5).toList();

  // Continue Watching (PRD §8.9): movies play directly; episodes resolve back
  // to their series (one card per series — the most-recent episode, since the
  // list is already updatedAt-desc).
  final progress =
      await ref.watch(watchProgressRepositoryProvider).recentlyWatched();
  final continueWatching = <ContinueEntry>[];
  final seenSeries = <String>{};
  // Providers routinely carry the SAME show under several language categories
  // ("| NL | Schitt's Creek", "| AR | Schitt's Creek") as separate series with
  // separate ids, so guarding on the id alone let one show appear twice.
  //
  // Matched on TitleKey rather than a bare string so the year still has a vote:
  // "The Office" (2005) and "The Office" (2001) normalise identically but are
  // different shows, and hiding a show you watched is a worse failure than
  // showing a duplicate. Kind-prefixed lists keep a film and a series of the
  // same name (Fargo) apart.
  final seenMovieKeys = <TitleKey>[];
  final seenSeriesKeys = <TitleKey>[];
  bool isNew(List<TitleKey> seen, TitleKey candidate) {
    if (seen.any((k) => k.matches(candidate))) return false;
    seen.add(candidate);
    return true;
  }

  for (final p in progress) {
    if (continueWatching.length >= 20) break;
    final key = parseContentKey(p.contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type == StreamType.movie.name) {
      // A finished film has nothing to continue.
      if (p.completed) continue;
      final movie = await catalog.movieById(account, key.id);
      if (movie == null) continue;
      if (!isNew(seenMovieKeys, titleKeyFor(movie.name, year: movie.year))) {
        continue;
      }
      continueWatching.add(ContinueEntry(
        progress: p,
        title: prettyTitle(movie.name, year: movie.year),
        imageUrl: movie.backdropUrl ?? movie.posterUrl,
        route: '/movie/${movie.id}',
        streamRef: StreamRef(
          accountId: account.id,
          type: StreamType.movie,
          streamId: movie.id,
          containerExt: movie.containerExt,
        ),
      ));
    } else if (key.type == StreamType.episode.name) {
      final episode = await catalog.episodeById(account, key.id);
      if (episode == null || !seenSeries.add(episode.seriesId)) continue;
      final series = await catalog.seriesById(account, episode.seriesId);
      if (series == null) continue;

      // Finishing an episode used to drop the whole show out of this rail.
      // Advance to the next episode instead — that is the thing you actually
      // want to watch next, and it is what the streaming services do.
      var showEpisode = episode;
      var showProgress = p;
      if (p.completed) {
        final all = await catalog.episodesOfSeries(account, episode.seriesId);
        final at = all.indexWhere((e) => e.id == episode.id);
        if (at == -1 || at + 1 >= all.length) continue; // Series finished.
        showEpisode = all[at + 1];
        // Start the next one from the beginning, keeping the ordering stamp so
        // the rail still sorts by when you last watched this show.
        showProgress = WatchProgress(
          contentKey: contentKeyFor(
              accountId: account.id,
              type: StreamType.episode,
              id: showEpisode.id),
          positionSeconds: 0,
          durationSeconds: showEpisode.durationSeconds ?? 0,
          updatedAt: p.updatedAt,
        );
      }
      if (!isNew(seenSeriesKeys, titleKeyFor(series.name, year: series.year))) {
        continue;
      }
      continueWatching.add(ContinueEntry(
        progress: showProgress,
        title: prettyTitle(series.name, year: series.year),
        subtitle:
            'S${showEpisode.seasonNumber} · E${showEpisode.episodeNumber}',
        imageUrl: series.backdropUrl ?? series.posterUrl,
        route: '/series/${series.id}',
        streamRef: StreamRef(
          accountId: account.id,
          type: StreamType.episode,
          streamId: showEpisode.id,
          containerExt: showEpisode.containerExt,
        ),
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
