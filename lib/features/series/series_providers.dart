import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
import '../../data/repositories/catalog_repository.dart';
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

/// Page size for the browse grid — mirrors the movies feed so a large catalog
/// is never held in memory all at once. Pagination lives in SeriesScreen.
const seriesPageSize = 90;

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
