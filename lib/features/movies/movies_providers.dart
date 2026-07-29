import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
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

/// Movies for one category (null = all), unsorted — the screen sorts. The
/// unscoped "All" list honours the content-language filter (an explicitly
/// picked category is already an allowed one).
final moviesListProvider =
    FutureProvider.family<List<Movie>, String?>((ref, categoryId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  final movies = await ref
      .watch(catalogRepositoryProvider)
      .movies(account, categoryId: categoryId);
  if (categoryId != null) return movies;
  final allowed =
      await ref.watch(allowedCategoryIdsProvider(CategoryType.vod).future);
  if (allowed == null) return movies;
  return movies.where((m) => allowed.contains(m.categoryId)).toList();
});

List<Movie> sortMovies(List<Movie> movies, MovieSort sort) {
  final sorted = [...movies];
  switch (sort) {
    case MovieSort.added:
      sorted.sort((a, b) => (b.addedAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.addedAt?.millisecondsSinceEpoch ?? 0));
    case MovieSort.name:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case MovieSort.rating:
      sorted.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
  }
  return sorted;
}

/// Watch progress for a content key (detail pages + episode rows).
final progressProvider = FutureProvider.family<WatchProgress?, String>(
    (ref, contentKey) =>
        ref.watch(watchProgressRepositoryProvider).get(contentKey));

final isFavoriteProvider = FutureProvider.family<bool, String>(
    (ref, contentKey) =>
        ref.watch(favoritesRepositoryProvider).isFavorite(contentKey));
