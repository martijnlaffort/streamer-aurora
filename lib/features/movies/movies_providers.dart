import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
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
/// memory budget and get it killed by the OS. Pagination lives in the screen
/// (MoviesScreen), which fetches one page at a time via the repository.
const moviesPageSize = 90;

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
