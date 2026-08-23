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

/// Sentinel category id for the Favourites filter on the Live tab. Not a real
/// catalogue category — it never reaches the repository.
const favoritesCategoryId = '__favorites__';

/// The user's favourite channels, resolved against the cached catalogue and
/// kept in the order they were added (newest first, as favourites are stored).
///
/// Favourites are content keys, so this is a handful of indexed lookups — there
/// is no scale concern here the way there is with the 25k-channel list itself.
/// A key for another account, or for a channel the playlist no longer carries,
/// is simply skipped: the Favourites row is a shortcut, not a source of truth.
final favoriteChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final favorites = await ref.watch(favoritesRepositoryProvider).all();
  final catalog = ref.watch(catalogRepositoryProvider);
  final channels = <Channel>[];
  for (final (contentKey, _) in favorites) {
    final key = parseContentKey(contentKey);
    if (key == null ||
        key.accountId != account.id ||
        key.type != StreamType.live.name) {
      continue;
    }
    final channel = await catalog.channelById(account, key.id);
    if (channel != null) channels.add(channel);
  }
  return channels;
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
    this.truncated = false,
  });

  final List<Channel> channels;

  /// Keyed by channel epgChannelId ?? id.
  final Map<String, List<EpgEntry>> programmes;

  /// UTC bounds of the loaded window.
  final DateTime windowStart;
  final DateTime windowEnd;

  /// More channels have EPG than are shown. Surfaced in the UI rather than
  /// silently dropped — a guide that quietly hides channels is worse than one
  /// that says it is showing the first N.
  final bool truncated;
}

/// How many channels the guide grid renders at once. The grid is a 2-D scroller
/// holding a row per channel; a line with 25k channels would build a 25k-row
/// grid and read every programme in the window (~300k rows) to do it.
const guideChannelLimit = 150;

final guideProvider = FutureProvider<GuideData?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;

  final now = DateTime.now().toUtc();
  // Window: from the top of the current hour to +12h, scrollable.
  final start = DateTime.utc(now.year, now.month, now.day, now.hour);
  final end = start.add(const Duration(hours: 12));

  // Start from the channels that HAVE EPG, not from the channel list. This is
  // the whole fix: the old flow loaded every channel plus every programme in
  // the window and intersected them in Dart.
  final epg = ref.watch(epgRepositoryProvider);
  final keys = await epg.channelKeysWithEpg(account, start, end,
      limit: guideChannelLimit);
  final truncated = keys.length > guideChannelLimit;
  final shown = (truncated ? keys.take(guideChannelLimit) : keys).toSet();

  final programmes =
      await epg.guideWindow(account, start, end, channelKeys: shown);
  final channels = await ref
      .watch(catalogRepositoryProvider)
      .channelsByEpgKeys(account, shown);

  // A key with no matching channel row (guide lists a channel the playlist
  // does not carry) simply has no row to draw.
  return GuideData(
    channels: channels
        .where(
            (c) => (programmes[c.epgChannelId ?? c.id] ?? const []).isNotEmpty)
        .toList(),
    programmes: programmes,
    windowStart: start,
    windowEnd: end,
    truncated: truncated,
  );
});
