import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/matching/channel_variant.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/category_chips.dart';
import '../../../core/widgets/focus_highlight.dart';
import '../../../core/widgets/shell_actions.dart';
import '../../../data/db/app_database.dart' show OverrideScope;
import '../../../data/providers.dart';
import '../../../data/repositories/catalog_overrides_repository.dart';
import '../../../domain/models/models.dart';
import '../../movies/movies_providers.dart' show isFavoriteProvider;
import '../../player/player_request.dart';
import '../live_providers.dart';
import 'multi_view_screen.dart';

/// Live TV (PRD §8.5): channel list with category filter and favorites,
/// now/next where the source provides EPG, tap to play.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  /// null = "All"; [favoritesCategoryId] = the favourites shortcut; otherwise a
  /// real catalogue category id.
  String? _categoryId;

  /// Set once the user picks a chip themselves, so the favourites default is
  /// only ever applied on arrival and never fights an explicit choice.
  bool _pickedCategory = false;

  /// Sort alphabetically instead of in the playlist's own order. Playlist order
  /// is the default, because that is the numbering people know their channels
  /// by; the letter index below only means anything once sorted A–Z.
  bool _byName = false;

  /// Selected letter from the A–Z index, or null for all.
  ///
  /// Deliberately a FILTER rather than a scroll-to-offset. On a 25k-channel line
  /// "jump to S" and "show me the S channels" are the same intent, and a filter
  /// composes correctly with paging — a real offset jump would need the list to
  /// hold thousands of rows it never loaded.
  String? _letter;

  /// The content-language filter in force for the current listing, captured so
  /// the player can zap through the same set the user is browsing.
  Set<String>? _allowedCategoryIds;
  final _scroll = ScrollController();

  final List<Channel> _items = [];
  bool _loading = false;
  bool _atEnd = false;
  Object? _error;

  /// Bumped whenever the category/filter changes, so a page still in flight
  /// from the previous query is discarded instead of appended.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
    _applyFavoritesDefault();
  }

  /// Land on Favourites when the user has some, so opening Live TV shows the
  /// channels they actually watch instead of the top of a 25k-channel list.
  ///
  /// Resolved ONCE here rather than in build: doing it in build meant either
  /// burning the decision on the empty list the provider returns while the
  /// channel cache is still cold, or leaving it live long enough to yank the
  /// filter out from under someone already browsing.
  Future<void> _applyFavoritesDefault() async {
    try {
      final favorites = await ref.read(favoriteChannelsProvider.future);
      if (!mounted || _pickedCategory || _categoryId != null) return;
      if (favorites.isEmpty) return;
      setState(() => _categoryId = favoritesCategoryId);
    } on Object {
      // Cosmetic preference — never worth surfacing.
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  static bool _sameIdSet(Set<String>? a, Set<String>? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.length == b.length && a.containsAll(b);
  }

  void _reload() {
    _generation++;
    _items.clear();
    _atEnd = false;
    _error = null;
    _loading = false;
    _loadMore();
  }

  Future<void> _loadMore() async {
    // Favourites are not paged from the catalogue — they come from the
    // favourites provider, so the sentinel must never reach the repository.
    if (_categoryId == favoritesCategoryId) return;
    if (_loading || _atEnd) return;
    _loading = true;
    final gen = _generation;
    try {
      final account = await ref.read(activeAccountProvider.future);
      if (account == null) {
        if (mounted && gen == _generation) setState(() => _atEnd = true);
        return;
      }
      final allowed = _categoryId == null
          ? await ref.read(allowedCategoryIdsProvider(CategoryType.live).future)
          : null;
      if (gen != _generation) return; // superseded during the awaits above
      // Kept so the player can reproduce this exact scope when zapping.
      _allowedCategoryIds = allowed;
      // Hidden channels are excluded in SQL, so pages still come back full.
      final overrides = await ref.read(catalogOverridesProvider.future);
      if (gen != _generation) return;
      final page = await ref.read(catalogRepositoryProvider).channels(
            account,
            categoryId: _categoryId,
            categoryIds: allowed,
            excludeIds: overrides.hiddenChannels,
            byName: _byName,
            namePrefix: _letter,
            groupVariants: ref.read(groupChannelVariantsProvider),
            limit: channelsPageSize,
            offset: _items.length,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page);
        if (page.length < channelsPageSize) _atEnd = true;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (gen == _generation) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload only on a REAL change. These providers are re-read after every
    // background sync, and reloading on each notification threw away the loaded
    // pages and the scroll position every couple of minutes for nothing.
    ref.listen(activeAccountProvider, (prev, next) {
      if (prev?.value?.id != next.value?.id) _reload();
    });
    ref.listen(allowedCategoryIdsProvider(CategoryType.live), (prev, next) {
      if (!_sameIdSet(prev?.value, next.value)) _reload();
    });
    // Collapsing changes what the pages CONTAIN, and the loaded pages are held
    // in `_items` — without this the switch in Settings appears to do nothing
    // until the tab is rebuilt from scratch.
    ref.listen(groupChannelVariantsProvider, (prev, next) {
      if (prev != next) _reload();
    });
    final categories = ref.watch(liveCategoriesProvider);
    final hasEpg = ref.watch(hasEpgProvider).value ?? false;
    final favorites =
        ref.watch(favoriteChannelsProvider).value ?? const <Channel>[];

    // Un-hearting the last favourite while looking at them: fall back to All.
    // In a listener, not in build — _reload() calls setState, and doing that
    // during a build is an error.
    ref.listen(favoriteChannelsProvider, (prev, next) {
      if ((next.value ?? const []).isEmpty &&
          _categoryId == favoritesCategoryId) {
        setState(() => _categoryId = null);
        _reload();
      }
    });

    // Favourites lead the filter and are pre-selected the first time they
    // resolve, so opening Live TV lands on the channels you actually watch
    // rather than the top of a 25k-channel list. The chip is absent entirely
    // when nothing is favourited — an empty Favourites row is just a dead end.
    //
    // Assigning here (no setState) is deliberate and safe: it happens on the
    // build that first sees the value, is consumed by that same build, and
    // needs no _reload() because favourites render from the provider rather
    // than from the paged `_items`.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          ShellActions(extra: [
            IconButton(
              icon: Icon(
                  _byName ? Icons.sort_by_alpha : Icons.format_list_numbered),
              tooltip: _byName ? 'Sorted A–Z' : 'Playlist order',
              onPressed: () {
                setState(() {
                  _byName = !_byName;
                  // The letter index only means anything alphabetically.
                  if (!_byName) _letter = null;
                });
                _reload();
              },
            ),
            if (hasEpg)
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'TV Guide',
                onPressed: () => context.push('/guide'),
              ),
          ]),
        ],
      ),
      body: Column(
        children: [
          categories.when(
            // A background sync must never blank a screen that already has
            // content: when() shows its loading branch on a reload by default.
            skipLoadingOnReload: true,
            data: (list) => list.isEmpty && favorites.isEmpty
                ? const SizedBox(height: 4)
                : CategoryChips(
                    categories: list,
                    selectedId: _categoryId,
                    leading: [
                      if (favorites.isNotEmpty)
                        (id: favoritesCategoryId, label: 'Favourites'),
                    ],
                    onSelected: (id) {
                      setState(() {
                        _pickedCategory = true;
                        _categoryId = id;
                      });
                      _reload();
                    },
                  ),
            loading: () => const SizedBox(height: 44),
            error: (e, _) => const SizedBox(height: 44),
          ),
          // The A–Z index, only while sorted alphabetically — in playlist order
          // a letter would pick out channels scattered through the whole list.
          if (_byName && _categoryId != favoritesCategoryId) _letterStrip(),
          Expanded(
            child: _categoryId == favoritesCategoryId
                ? _favoritesList(favorites)
                : _list(),
          ),
        ],
      ),
    );
  }

  /// A–Z index. Tapping a letter narrows the list to it; tapping it again, or
  /// "All", clears it.
  Widget _letterStrip() {
    const letters = [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    ];
    // (id, label) so "All" can sit at the front without a special case below.
    final entries = <({String? value, String label})>[
      (value: null, label: 'All'),
      for (final l in letters) (value: l, label: l),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (context, i) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final entry = entries[i];
          final selected = _letter == entry.value;
          return FocusHighlight(
            borderRadius: 16,
            scale: 1.0,
            ensureVisible: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              focusColor: Colors.transparent,
              onTap: () {
                setState(() => _letter = selected ? null : entry.value);
                _reload();
              },
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.28)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.surfaceElevated),
                ),
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The favourites row. Not paged — favourites are a handful of channels, and
  /// they come straight from the provider so hearting one here updates the list
  /// under you rather than leaving a stale row behind.
  Widget _favoritesList(List<Channel> favorites) {
    if (favorites.isEmpty) {
      return Center(
        child: Text('No favourite channels yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: favorites.length,
      // No ZapContext: channel up/down resolves neighbours by INDEX into the
      // catalogue list, and a favourite's position in this list has nothing to
      // do with its position there — zapping would jump to unrelated channels.
      // Better to have no channel up/down here than wrong channel up/down.
      itemBuilder: (context, i) => _ChannelTile(channel: favorites[i]),
    );
  }

  Widget _list() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
            child: Text('$_error',
                style: TextStyle(color: AppColors.error)));
      }
      return Center(
        child: Text('No channels in this playlist.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _items.length,
      // The tile is handed its position and the list's scope so the player can
      // offer channel up/down from the same ordering the user is looking at.
      itemBuilder: (context, i) => _ChannelTile(
        channel: _items[i],
        zap: ZapContext(
          index: i,
          categoryId: _categoryId,
          categoryIds: _categoryId == null ? _allowedCategoryIds : null,
        ),
      ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel, this.zap});

  final Channel channel;

  /// Position and scope within the list this tile belongs to — enables channel
  /// up/down once playing.
  final ZapContext? zap;

  String get _contentKey => contentKeyFor(
      accountId: channel.accountId, type: StreamType.live, id: channel.id);

  /// Plays this channel, or [variant] when the user picked a specific quality
  /// from a collapsed group.
  void _play(BuildContext context,
      {String? nowTitle, Channel? variant, String? title}) {
    final target = variant ?? channel;
    context.push(
      '/player',
      extra: PlayerRequest(
        queue: [
          PlayerItem(
            streamRef: StreamRef(
              accountId: target.accountId,
              type: StreamType.live,
              streamId: target.id,
            ),
            title: title ?? target.name,
            subtitle: nowTitle != null ? 'Now: $nowTitle' : null,
            // The GROUP's key, deliberately, even when a specific variant is
            // playing: the heart on this row toggles that key, so keying
            // progress to the variant instead would let "is this a favourite"
            // disagree with what the row shows.
            contentKey: _contentKey,
            isLive: true,
          ),
        ],
        zap: zap,
      ),
    );
  }

  /// Rename / hide, in a sheet rather than a popup menu so it is operable with a
  /// remote (the first row takes focus).
  Future<void> _showChannelMenu(BuildContext context, WidgetRef ref,
      String displayName, CatalogOverrides overrides) async {
    final custom = overrides.channelNames[channel.id];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title),
              ),
            ),
            ListTile(
              autofocus: true,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename channel'),
              subtitle: custom == null
                  ? null
                  : Text('Playlist name: ${channel.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameChannel(context, ref, custom);
              },
            ),
            if (channel.variantKey != null)
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('Choose quality…'),
                subtitle: Text('Pick a different stream for this channel',
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showQualityPicker(context, ref, displayName);
                },
              ),
            ListTile(
              leading: const Icon(Icons.splitscreen_outlined),
              title: const Text('Watch alongside…'),
              subtitle: Text('Two channels side by side',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final other = await pickCompanionChannel(context, channel);
                if (other == null || !context.mounted) return;
                context.push('/multiview', extra: <Channel>[channel, other]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide channel'),
              subtitle: Text('Undo in Settings → Hidden channels',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final account = await ref.read(activeAccountProvider.future);
                if (account == null) return;
                await ref.read(catalogOverridesRepositoryProvider).setHidden(
                      accountId: account.id,
                      scope: OverrideScope.channel,
                      targetId: channel.id,
                      hidden: true,
                    );
                ref.invalidate(catalogOverridesProvider);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// The other streams the line carries for this channel.
  ///
  /// Read on demand rather than carried on every row: on a 25k line that would
  /// be an extra query per visible tile for something most people never open.
  Future<void> _showQualityPicker(
      BuildContext context, WidgetRef ref, String displayName) async {
    final key = channel.variantKey;
    final account = await ref.read(activeAccountProvider.future);
    if (key == null || account == null || !context.mounted) return;
    final variants =
        await ref.read(catalogRepositoryProvider).channelVariants(account, key);
    if (!context.mounted) return;
    if (variants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This channel only has one stream.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title),
              ),
            ),
            for (final (i, variant) in variants.indexed)
              ListTile(
                autofocus: i == 0,
                leading: Icon(
                  variant.id == channel.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: variant.id == channel.id
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                title: Text(
                    parseChannelVariant(variant.name).qualityLabel ??
                        'Default',
                    maxLines: 1),
                // The provider's own name for it, so two rows that resolve to
                // the same label are still tellable apart.
                subtitle: Text(variant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _play(context, variant: variant, title: displayName);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renameChannel(
      BuildContext context, WidgetRef ref, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename channel'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: channel.name,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
          // Empty restores the playlist's own name, so there is no separate
          // "clear" action to hunt for.
          TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Use original')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).setName(
          accountId: account.id,
          scope: OverrideScope.channel,
          targetId: channel.id,
          name: name,
        );
    ref.invalidate(catalogOverridesProvider);
    ref.invalidate(favoriteChannelsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = ref.watch(nowNextProvider(channel)).value ?? const [];
    final now = nowNext.isNotEmpty ? nowNext.first : null;
    final next = nowNext.length > 1 ? nowNext[1] : null;
    final favorite = ref.watch(isFavoriteProvider(_contentKey)).value ?? false;
    final overrides =
        ref.watch(catalogOverridesProvider).value ?? CatalogOverrides.empty;
    // Collapsed rows show the channel without its quality tag; a user rename
    // still wins over both.
    final grouped = ref.watch(groupChannelVariantsProvider);
    final displayName = overrides.channelName(
        channel.id, grouped ? channel.displayName : channel.name);
    // What the row will actually play, so a collapsed group says which of its
    // variants won rather than leaving the user to guess.
    final quality =
        grouped ? parseChannelVariant(channel.name).qualityLabel : null;

    // The play area and the heart are SIBLINGS, not a ListTile with a trailing
    // button. That is what makes the heart reachable with a remote: a ListTile's
    // own InkWell spans the whole row, so its focus rect CONTAINS the trailing
    // button's — and directional traversal will not move to a target that is not
    // actually beside it, so D-pad RIGHT never found the heart. Two adjacent
    // focusables with disjoint rects traverse the way you would expect.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          Expanded(
            // No ensureVisible: this is a vertical list, and Flutter's own
            // focus traversal already scrolls the focused row into view. Adding
            // ours produced a snap followed by a second 220ms glide.
            child: FocusHighlight(
              scale: 1.0,
              child: InkWell(
                onTap: () => _play(context, nowTitle: now?.title),
                borderRadius: BorderRadius.circular(12),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      _Logo(url: channel.logoUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (quality != null) ...[
                                  const SizedBox(width: 6),
                                  _QualityChip(quality),
                                ],
                              ],
                            ),
                            if (now != null) ...[
                              const SizedBox(height: 2),
                              Text('Now: ${now.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.accentAlt,
                                      fontSize: 13)),
                              if (next != null)
                                Text('Next: ${next.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              const SizedBox(height: 4),
                              _ProgrammeProgress(entry: now),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.play_circle_outline,
                          color: AppColors.textSecondary, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          FocusHighlight(
            borderRadius: 24,
            scale: 1.0,
            child: IconButton(
              tooltip: favorite ? 'Remove from favourites' : 'Add to favourites',
              icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: favorite ? AppColors.accent : AppColors.textSecondary),
              onPressed: () async {
                await ref.read(favoritesRepositoryProvider).toggle(_contentKey);
                ref.invalidate(isFavoriteProvider(_contentKey));
                // The Favourites row reads this list, so it has to be told.
                ref.invalidate(favoriteChannelsProvider);
              },
            ),
          ),
          // A third sibling, for the same reason the heart is one: nested in the
          // row's own InkWell it would be unreachable with a D-pad.
          FocusHighlight(
            borderRadius: 24,
            scale: 1.0,
            child: IconButton(
              tooltip: 'More',
              icon: Icon(Icons.more_vert,
                  size: 22, color: AppColors.textSecondary),
              onPressed: () =>
                  _showChannelMenu(context, ref, displayName, overrides),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quality a collapsed row is about to play (`HD`, `FHD`, `4K`).
///
/// Small and muted on purpose: it is a footnote to the channel name, not a
/// badge competing with it.
class _QualityChip extends StatelessWidget {
  const _QualityChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(4),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              memCacheWidth: 200,
              errorWidget: (context, u, e) => Icon(Icons.live_tv,
                  color: AppColors.textSecondary),
            )
          : Icon(Icons.live_tv, color: AppColors.textSecondary),
    );
  }
}

/// Thin bar showing how far through the current programme we are (UTC math,
/// PRD §8.5).
class _ProgrammeProgress extends StatelessWidget {
  const _ProgrammeProgress({required this.entry});

  final EpgEntry entry;

  @override
  Widget build(BuildContext context) {
    final total = entry.stop.difference(entry.start).inSeconds;
    final elapsed = DateTime.now().toUtc().difference(entry.start).inSeconds;
    final fraction = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 3,
        backgroundColor: AppColors.surfaceElevated,
        color: AppColors.accent,
      ),
    );
  }
}
