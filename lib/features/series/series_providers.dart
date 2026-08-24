import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rotation.dart';
import '../../data/db/app_database.dart' show CatalogKind;
import '../../data/providers.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/models.dart';
import '../movies/movies_providers.dart' show categoryRailLength;

enum SeriesSort { name, rating }

extension SeriesSortLabel on SeriesSort {
  String get label => switch (this) {
        SeriesSort.name => 'Name',
        SeriesSort.rating => 'Rating',
      };
}

final seriesCategoriesProvider = FutureProvider<List<Category>>(
    (ref) => visibleCategories(ref, CategoryType.series));

/// Page size for the browse grid — mirrors the movies feed so a large catalog
/// is never held in memory all at once. Pagination lives in [PagedPosterGrid].
const seriesPageSize = 90;

/// One category's rail. See [movieCategoryRailProvider] for why this is
/// cache-first, non-blocking and debounced — a line can have hundreds of
/// categories and warming one pulls the whole category.
final seriesCategoryRailProvider =
    FutureProvider.autoDispose.family<List<Series>, String>(
        (ref, categoryId) async {
  var gone = false;
  ref.onDispose(() => gone = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (gone) return const [];

  // Past the dwell, this is a rail the user actually stopped on — so keep the
  // result for a few minutes instead of letting autoDispose drop it the moment
  // it scrolls out of view.
  //
  // Without this, every scroll past a rail disposed it, and scrolling back re-ran
  // the dwell, re-showed a placeholder and re-decided the row's height. Dozens
  // of rails doing that is what made the tab look like it was reloading itself,
  // and when enough of them collapsed at once the list became shorter than the
  // scroll offset and threw you back to the top. A fast flick still costs
  // nothing — those disposals happen during the dwell above.
  final keepAlive = ref.keepAlive();
  Timer(const Duration(minutes: 5), keepAlive.close);

  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final catalog = ref.watch(catalogRepositoryProvider);

  // See movieCategoryRailProvider — a different slice per session, salted so
  // the rails do not all turn the page together.
  final page = rotatingPage(
      seed: ref.watch(rotationSeedProvider), pages: 3, salt: categoryId);

  Future<List<Series>> fromCache({int page = 0}) => catalog.series(
        account,
        categoryId: categoryId,
        limit: categoryRailLength,
        offset: page * categoryRailLength,
        refresh: false,
      );

  var cached = await fromCache(page: page);
  if (cached.isEmpty && page > 0) cached = await fromCache();
  if (cached.isNotEmpty) {
    catalog.warmCategory(account, CatalogKind.series, categoryId).ignore();
    return cached;
  }
  if (gone) return const [];
  await catalog.warmCategory(account, CatalogKind.series, categoryId);
  final warmed = await fromCache(page: page);
  return warmed.isEmpty ? await fromCache() : warmed;
});

/// Maps the UI sort to the DB-side ordering used for paged reads. Pagination is
/// driven by SeriesScreen directly against the repository.
SeriesOrder seriesOrderFor(SeriesSort sort) => switch (sort) {
      SeriesSort.name => SeriesOrder.nameAsc,
      SeriesSort.rating => SeriesOrder.ratingDesc,
    };

/// Seasons + episodes (source-fetched, cache-backed offline).
final seriesDetailProvider =
    FutureProvider.family<SeriesDetail?, String>((ref, seriesId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  return ref.watch(catalogRepositoryProvider).seriesDetail(account, seriesId);
});

/// Watch progress for every episode of a series, keyed by content key.
final seriesProgressProvider =
    FutureProvider.family<Map<String, WatchProgress>, String>(
        (ref, seriesId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const {};
  final detail = await ref.watch(seriesDetailProvider(seriesId).future);
  if (detail == null) return const {};
  final repo = ref.watch(watchProgressRepositoryProvider);
  final result = <String, WatchProgress>{};
  for (final episode in detail.episodes) {
    final key = contentKeyFor(
        accountId: account.id, type: StreamType.episode, id: episode.id);
    final progress = await repo.get(key);
    if (progress != null) result[key] = progress;
  }
  return result;
});
