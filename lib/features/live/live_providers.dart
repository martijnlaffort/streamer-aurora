import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/models.dart';

final liveCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  return ref
      .watch(catalogRepositoryProvider)
      .categories(account, CategoryType.live);
});

/// Channels for one category (null = all).
final channelsListProvider =
    FutureProvider.family<List<Channel>, String?>((ref, categoryId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  return ref
      .watch(catalogRepositoryProvider)
      .channels(account, categoryId: categoryId);
});

/// Now/Next for a channel (PRD §8.5). Empty for sources without EPG (plain
/// M3U). autoDispose so off-screen rows release their fetch; the repository
/// caches results with a short TTL so scrolling back is instant.
final nowNextProvider =
    FutureProvider.autoDispose.family<List<EpgEntry>, Channel>(
        (ref, channel) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  return ref
      .watch(catalogRepositoryProvider)
      .shortEpg(account, channel, limit: 2);
});
