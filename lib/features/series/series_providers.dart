import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';

enum SeriesSort { name, rating }

extension SeriesSortLabel on SeriesSort {
  String get label => switch (this) {
        SeriesSort.name => 'Name',
        SeriesSort.rating => 'Rating',
      };
}

final seriesCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  final cats = await ref
      .watch(catalogRepositoryProvider)
      .categories(account, CategoryType.series);
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  if (enabled == null) return cats;
  return cats
      .where((c) => enabled.contains(detectContentLanguage(c.name).code))
      .toList();
});

final seriesListProvider =
    FutureProvider.family<List<Series>, String?>((ref, categoryId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  final series = await ref
      .watch(catalogRepositoryProvider)
      .series(account, categoryId: categoryId);
  if (categoryId != null) return series;
  final allowed =
      await ref.watch(allowedCategoryIdsProvider(CategoryType.series).future);
  if (allowed == null) return series;
  return series.where((s) => allowed.contains(s.categoryId)).toList();
});

List<Series> sortSeries(List<Series> series, SeriesSort sort) {
  final sorted = [...series];
  switch (sort) {
    case SeriesSort.name:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SeriesSort.rating:
      sorted.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
  }
  return sorted;
}

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
