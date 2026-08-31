import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/models.dart';

final liveCategoriesProvider = FutureProvider<List<Category>>(
    (ref) => visibleCategories(ref, CategoryType.live));

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
  final overrides = await ref.watch(catalogOverridesProvider.future);
  return ref.watch(epgRepositoryProvider).nowNext(
        account,
        channel,
        limit: 2,
        epgKeyOverride: overrides.epgIds[channel.id],
      );
});

/// How much of the channel list the guide covers.
///
/// Surfaced rather than left silent: a channel with no guide data looks
/// identical to a broken app, and the count is what turns "the guide doesn't
/// work" into "1,847 channels have no guide data, here they are".
final guideCoverageProvider =
    FutureProvider<({int total, int covered})?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  // Recount when a mapping is added, or the number would never improve.
  ref.watch(catalogOverridesProvider);
  return ref.watch(epgRepositoryProvider).guideCoverage(account);
});

/// The channels the guide has nothing for, for the mapping screen.
final channelsWithoutEpgProvider = FutureProvider<List<Channel>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  ref.watch(catalogOverridesProvider);
  return ref.watch(epgRepositoryProvider).channelsWithoutEpg(account);
});

/// Guide keys the EPG actually holds — the options a manual mapping can pick.
final knownEpgKeysProvider = FutureProvider<List<String>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  return ref.watch(epgRepositoryProvider).knownEpgKeys(account);
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
    this.epgIds = const {},
  });

  /// Hand-set channel → XMLTV mappings, so the grid reads each row under the
  /// same key the provider built it with.
  final Map<String, String> epgIds;

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

  // Channels the user mapped by hand belong in the grid even though the
  // playlist's own id matched nothing — that mapping IS the fix, and it would
  // be perverse to keep hiding the row that proves it worked.
  final overrides = await ref.watch(catalogOverridesProvider.future);
  final withMapped = {...shown, ...overrides.epgIds.values};

  final programmes =
      await epg.guideWindow(account, start, end, channelKeys: withMapped);
  final catalog = ref.watch(catalogRepositoryProvider);
  final channels = <Channel>[
    ...await catalog.channelsByEpgKeys(account, shown),
  ];
  final seen = {for (final c in channels) c.id};
  for (final entry in overrides.epgIds.entries) {
    if (seen.contains(entry.key)) continue;
    final mapped = await catalog.channelById(account, entry.key);
    if (mapped != null) channels.add(mapped);
  }

  // A key with no matching channel row (guide lists a channel the playlist
  // does not carry) simply has no row to draw.
  return GuideData(
    channels: channels
        .where((c) =>
            (programmes[overrides.epgKey(c.id, c.epgChannelId ?? c.id)] ??
                    const [])
                .isNotEmpty)
        .toList(),
    epgIds: overrides.epgIds,
    programmes: programmes,
    windowStart: start,
    windowEnd: end,
    truncated: truncated,
  );
});
