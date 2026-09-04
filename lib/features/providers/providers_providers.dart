import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/matching/provider_brand.dart';
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
