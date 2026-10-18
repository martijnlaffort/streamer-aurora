import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/matching/provider_brand.dart';
import '../../core/matching/title_match.dart';
import '../../data/db/app_database.dart' show CatalogKind;
import '../../data/providers.dart';
import '../../data/repositories/catalog_repository.dart'
    show MovieOrder, SeriesOrder;
import '../movies/movies_providers.dart';
import '../series/series_providers.dart';
import '../../domain/models/models.dart';

/// One streaming service as it appears in this playlist, with the categories
/// that belong to it.
class ProviderShelf {
  const ProviderShelf({
    required this.brand,
    required this.movieCategories,
    required this.seriesCategories,
  });

  final ProviderBrand brand;
  final List<Category> movieCategories;
  final List<Category> seriesCategories;

  int get categoryCount => movieCategories.length + seriesCategories.length;
}

/// Every service detected in the active account's VOD and series categories.
///
/// Built from the categories the user can actually see — the same
/// language-filtered, unhidden list the Movies and Series tabs browse — so
/// hiding a group removes it from here too rather than leaving a provider
/// that leads nowhere.
final providerShelvesProvider =
    FutureProvider<List<ProviderShelf>>((ref) async {
  final movies = await ref.watch(vodCategoriesProvider.future);
  final series = await ref.watch(seriesCategoriesProvider.future);

  final byBrand = <String, ({ProviderBrand brand, List<Category> m, List<Category> s})>{};
  void add(Category c, bool isMovie) {
    final brand = detectProviderBrand(c.name);
    if (brand == null) return;
    final entry = byBrand.putIfAbsent(
        brand.id, () => (brand: brand, m: <Category>[], s: <Category>[]));
    (isMovie ? entry.m : entry.s).add(c);
  }

  for (final c in movies) {
    add(c, true);
  }
  for (final c in series) {
    add(c, false);
  }

  final shelves = [
    for (final e in byBrand.values)
      ProviderShelf(
          brand: e.brand, movieCategories: e.m, seriesCategories: e.s),
  ];
  // Most-carried first: on a line with three Netflix groups and one stray
  // Peacock category, the order should say which is worth opening.
  shelves.sort((a, b) {
    final byCount = b.categoryCount.compareTo(a.categoryCount);
    return byCount != 0 ? byCount : a.brand.name.compareTo(b.brand.name);
  });
  return shelves;
});

/// One service, looked up by its brand id.
final providerShelfProvider =
    FutureProvider.family<ProviderShelf?, String>((ref, id) async {
  final shelves = await ref.watch(providerShelvesProvider.future);
  return shelves.where((s) => s.brand.id == id).firstOrNull;
});

/// The rails a service's page opens with, drawn across ALL of that service's
/// categories rather than from any one of them.
class ProviderHighlights {
  const ProviderHighlights({
    this.newMovies = const [],
    this.topMovies = const [],
    this.topSeries = const [],
  });

  final List<Movie> newMovies;
  final List<Movie> topMovies;
  final List<Series> topSeries;

  bool get isEmpty =>
      newMovies.isEmpty && topMovies.isEmpty && topSeries.isEmpty;

  /// Identity of the contents, to tell whether a re-read found anything new.
  String get signature => [
        for (final m in newMovies) m.id,
        '|',
        for (final m in topMovies) m.id,
        '|',
        for (final s in topSeries) s.id,
      ].join(',');
}

/// "New on Disney+", "Top rated on Disney+", "Top rated series on Disney+".
///
/// A service page used to be the panel's own groups for that service, one
/// rail each, in the panel's order and under the panel's names — `DISNEY+ 4K`,
/// `DISNEY+ NL`, `DISNEY+ KIDS` — the same titles repeated across them, and
/// nothing that said where to start. These rails are what a viewer opens a
/// service for; the panel's groups follow underneath.
///
/// Served from cache at once; the service's categories are then brought up to
/// date in the background, and the rails rebuild only if that found anything.
final providerHighlightsProvider = FutureProvider.autoDispose
    .family<ProviderHighlights, String>((ref, brandId) async {
  final shelf = await ref.watch(providerShelfProvider(brandId).future);
  final account = await ref.watch(activeAccountProvider.future);
  if (shelf == null || account == null) return const ProviderHighlights();
  final catalog = ref.watch(catalogRepositoryProvider);
  final movieIds = {for (final c in shelf.movieCategories) c.id};
  final seriesIds = {for (final c in shelf.seriesCategories) c.id};

  // Over-fetched, because the same title sits in several of a service's groups
  // (the 4K copy and the HD copy) and duplicates are dropped below.
  const pool = categoryRailLength * 4;
  Future<ProviderHighlights> read() async {
    final newest = await catalog.movies(account,
        categoryIds: movieIds,
        order: MovieOrder.addedDesc,
        limit: pool,
        refresh: false);
    final topMovies = await catalog.movies(account,
        categoryIds: movieIds,
        order: MovieOrder.ratingDesc,
        limit: pool,
        refresh: false);
    final topSeries = await catalog.series(account,
        categoryIds: seriesIds,
        order: SeriesOrder.ratingDesc,
        limit: pool,
        refresh: false);
    return ProviderHighlights(
      newMovies: _distinct(newest, (m) => (m.name, m.year)),
      // A panel that rates nothing sorts arbitrarily; "top rated" of unrated
      // titles would be a lie, so unrated ones are left out.
      topMovies: _distinct(
          topMovies.where((m) => (m.rating ?? 0) > 0), (m) => (m.name, m.year)),
      topSeries: _distinct(
          topSeries.where((s) => (s.rating ?? 0) > 0), (s) => (s.name, s.year)),
    );
  }

  final cached = await read();
  Future<void> warmAll() async {
    // One at a time: the repository serializes downloads anyway, and warm
    // drops requests past a small queue.
    for (final id in movieIds) {
      await catalog.warmCategory(account, CatalogKind.vod, id);
    }
    for (final id in seriesIds) {
      await catalog.warmCategory(account, CatalogKind.series, id);
    }
  }

  if (cached.isEmpty) {
    // Nothing to show yet — this is the one case worth waiting for.
    try {
      await warmAll();
    } on Object {
      return cached;
    }
    return read();
  }
  var gone = false;
  ref.onDispose(() => gone = true);
  unawaited(() async {
    try {
      await warmAll();
      if (gone) return;
      final fresh = await read();
      if (!gone && fresh.signature != cached.signature) ref.invalidateSelf();
    } on Object {
      // Offline or the panel is down — the cached rails stand.
    }
  }());
  return cached;
});

/// The first [categoryRailLength] of [items] with one entry per title — the
/// same film in a service's 4K group and its HD group is one card, not two.
List<T> _distinct<T>(Iterable<T> items, (String, int?) Function(T) title) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in items) {
    final (name, year) = title(item);
    if (!seen.add('${normalizeTitle(name, knownYear: year)}@$year')) continue;
    out.add(item);
    if (out.length == categoryRailLength) break;
  }
  return out;
}
