import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/db/app_database.dart' show CatalogKind;
import '../../data/providers.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/models.dart';

enum MovieSort { added, name, rating }

extension MovieSortLabel on MovieSort {
  String get label => switch (this) {
        MovieSort.added => 'Recently added',
        MovieSort.name => 'Name',
        MovieSort.rating => 'Rating',
      };
}

final vodCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  final cats = await ref
      .watch(catalogRepositoryProvider)
      .categories(account, CategoryType.vod);
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  if (enabled == null) return cats;
  return cats
      .where((c) => enabled.contains(detectContentLanguage(c.name).code))
      .toList();
});

/// Page size for the browse grid. Small enough that the grid never holds the
/// whole catalog in memory — a large catalog would otherwise blow the app's
/// memory budget and get it killed by the OS. Pagination lives in
/// [PagedPosterGrid], which fetches one page at a time via the repository.
const moviesPageSize = 90;

/// How many posters one category rail shows before "See all".
const categoryRailLength = 15;

/// Route sentinel for "no category filter" — the unscoped grid reachable from
/// the Movies/Series app bar. Not a real category id, so it cannot collide with
/// one from a panel.
const allCategoryId = '__all__';

/// How long a rail must stay on screen before it is allowed to fetch.
///
/// The Movies tab is one rail per category, and a line can have hundreds. Since
/// the panel offers no per-category limit, warming a category downloads the
/// whole category — so a fling from top to bottom must not queue a fetch per
/// rail. Rails that scroll past within this window are disposed before they ask
/// for anything, which makes fast scrolling free.
const _railDwell = Duration(milliseconds: 350);

/// One category's rail. Cache-first and non-blocking: it never waits on the
/// network to render, and only warms its own category once the user has
/// actually stopped on it.
final movieCategoryRailProvider =
    FutureProvider.autoDispose.family<List<Movie>, String>(
        (ref, categoryId) async {
  // autoDispose + this flag are the debounce: scrolling away disposes the
  // provider during the pause below, and we bail before issuing anything.
  var gone = false;
  ref.onDispose(() => gone = true);
  await Future<void>.delayed(_railDwell);
  if (gone) return const [];

  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final catalog = ref.watch(catalogRepositoryProvider);

  Future<List<Movie>> fromCache() => catalog.movies(
        account,
        categoryId: categoryId,
        limit: categoryRailLength,
        order: MovieOrder.addedDesc,
        refresh: false,
      );

  final cached = await fromCache();
  if (cached.isNotEmpty) {
    // Something to show: render it and let a stale category catch up behind us.
    catalog.warmCategory(account, CatalogKind.vod, categoryId).ignore();
    return cached;
  }
  if (gone) return const [];
  // Nothing cached — this is the one case worth waiting for, and it is a single
  // category, not a sweep.
  await catalog.warmCategory(account, CatalogKind.vod, categoryId);
  return fromCache();
});

/// Maps the UI sort to the DB-side ordering used for paged reads. The screen
/// (MoviesScreen) drives pagination directly against the repository, so no
/// per-page provider is needed.
MovieOrder movieOrderFor(MovieSort sort) => switch (sort) {
      MovieSort.added => MovieOrder.addedDesc,
      MovieSort.name => MovieOrder.nameAsc,
      MovieSort.rating => MovieOrder.ratingDesc,
    };

/// Watch progress for a content key (detail pages + episode rows).
final progressProvider = FutureProvider.family<WatchProgress?, String>(
    (ref, contentKey) =>
        ref.watch(watchProgressRepositoryProvider).get(contentKey));

final isFavoriteProvider = FutureProvider.family<bool, String>(
    (ref, contentKey) =>
        ref.watch(favoritesRepositoryProvider).isFavorite(contentKey));
