import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language/content_language.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';

final liveCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return [];
  final cats = await ref
      .watch(catalogRepositoryProvider)
      .categories(account, CategoryType.live);
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  if (enabled == null) return cats;
  return cats
      .where((c) => enabled.contains(detectContentLanguage(c.name).code))
      .toList();
});

/// Page size for the Live channel list. The list used to load every channel at
/// once and filter in Dart; on a line with tens of thousands of channels that
/// materialised the whole lot into models on every read of the tab. LiveScreen
/// pages against the repository instead, and the language filter is applied in
/// SQL so pages come back full.
const channelsPageSize = 90;

/// Now/Next for a channel (PRD §8.5), from the ingested XMLTV guide (or a
/// per-channel fallback for Xtream). Empty for accounts without any EPG.
/// autoDispose so off-screen rows release their fetch; the repository caches
/// so scrolling back is instant.
final nowNextProvider =
    FutureProvider.autoDispose.family<List<EpgEntry>, Channel>(
        (ref, channel) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  return ref.watch(epgRepositoryProvider).nowNext(account, channel, limit: 2);
});

/// Whether the active account has any EPG data (drives the guide entry point).
final hasEpgProvider = FutureProvider<bool>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return false;
  return ref.watch(epgRepositoryProvider).hasEpg(account);
});

/// The EPG guide grid: channels + their programmes over a time window.
class GuideData {
  const GuideData({
    required this.channels,
    required this.programmes,
    required this.windowStart,
    required this.windowEnd,
  });

  final List<Channel> channels;

  /// Keyed by channel epgChannelId ?? id.
  final Map<String, List<EpgEntry>> programmes;

  /// UTC bounds of the loaded window.
  final DateTime windowStart;
  final DateTime windowEnd;
}

final guideProvider = FutureProvider<GuideData?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;

  final now = DateTime.now().toUtc();
  // Window: from the top of the current hour to +12h, scrollable.
  final start = DateTime.utc(now.year, now.month, now.day, now.hour);
  final end = start.add(const Duration(hours: 12));

  final channels = await ref.watch(catalogRepositoryProvider).channels(account);
  final programmes =
      await ref.watch(epgRepositoryProvider).guideWindow(account, start, end);

  // Only show channels that actually have EPG in the window.
  final withEpg = channels
      .where((c) => (programmes[c.epgChannelId ?? c.id] ?? const []).isNotEmpty)
      .toList();

  return GuideData(
    channels: withEpg,
    programmes: programmes,
    windowStart: start,
    windowEnd: end,
  );
});
