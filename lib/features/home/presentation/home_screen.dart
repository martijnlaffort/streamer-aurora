import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/television.dart';
import '../../../core/rotation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../core/matching/title_label.dart';
import '../../../domain/models/models.dart';
import '../../player/player_request.dart';
import '../home_providers.dart';
import 'widgets/media_rail.dart';

/// Home (PRD Â§8.2): rotating featured hero, Continue Watching, Recently
/// Added, and per-category rails â€” all served from the cached catalog.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);

    return Scaffold(
      body: home.when(
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e,
            title: 'Could not load your catalogue',
            onRetry: () => ref.invalidate(homeDataProvider)),

        data: (data) =>
            data == null ? const _NoAccount() : _HomeContent(data: data),
      ),
    );
  }
}

class _NoAccount extends ConsumerWidget {
  const _NoAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = isTelevisionOf(ref);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dawn Player', style: AppTypography.display),
          const SizedBox(height: 8),
          Text(
            tv
                ? 'Pair with your phone to bring your playlists across.'
                : 'Add a playlist to light this screen up.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          // On a television, pairing is THE way in â€” typing a server URL, a
          // username and a password with a D-pad is the thing pairing exists to
          // avoid. It was previously reachable only through Settings, i.e. only
          // through the rail, which left a fresh TV with no way to reach it at
          // all. It leads here, and takes the initial focus so the remote has
          // somewhere to start.
          if (tv) ...[
            FilledButton.icon(
              autofocus: true,
              onPressed: () => context.push('/pair/receive'),
              icon: const Icon(Icons.phonelink_ring),
              label: const Text('Pair with your phone'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/accounts'),
              icon: const Icon(Icons.add),
              label: const Text('Or add a playlist manually'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => context.push('/accounts'),
              icon: const Icon(Icons.add),
              label: const Text('Add your first account'),
            ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        // This used to call refreshCatalog(), which sweeps the ENTIRE vod
        // slice â€” 150k titles on a real line, i.e. minutes of spinner for a
        // pull-to-refresh, while the Movies and Series tabs returned instantly
        // because they only re-read. It was the last whole-slice sweep left in
        // a routine path.
        //
        // Refreshing the catalogue is not what this gesture is for: the rails
        // are served from cache and each category refreshes itself on demand.
        // So re-read, and deal a new rotation, which is the "show me something
        // else" the gesture actually means.
        ref.invalidate(rotationSeedProvider);
        ref.invalidate(homeDataProvider);
        ref.invalidate(myListProvider);
        ref.invalidate(discoveryRailsProvider);
        // Let the new values land so the spinner reflects real work.
        await ref.read(homeDataProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          // The featured hero used to fill the top, but it only ever spotlit an
          // unfamiliar recently-added title, so Home now opens straight into
          // Continue Watching and the rails. This just clears the status bar /
          // overscan the hero used to sit behind. (On TV the shell routes the
          // first D-pad press into the content, so nothing needs autofocus.)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).top + 8),
          ),
          if (data.continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: MediaRail(
                title: 'Continue Watching',
                height: 188,
                itemCount: data.continueWatching.length,
                itemBuilder: (context, i) =>
                    _ContinueCard(entry: data.continueWatching[i]),
              ),
            ),
          ..._myListSlivers(context, ref),
          // Externally-ranked rails (Top 10, Trending, New Releases, Award
          // Winners). Separate provider â€” Home never waits on them.
          ..._discoverySlivers(context, ref),
          // The seasonal rail, when there is one. Placed above the discovery
          // rails on purpose: for the few weeks it appears it is the most
          // topical thing on the screen, and it costs no network to produce.
          ..._seasonalSlivers(context, ref),
          // The Top Rated and Recently Added rails are gone: Top Rated was the
          // panel's own rating with no vote count (the discovery rails above
          // replaced it), and Recently Added just surfaced arbitrary, unknown
          // uploads. Per-category rails moved to the Movies and Series tabs.
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// A poster for a Movie **or** Series. Discovery rails and My List both hold
/// mixed model types, so the branch lives in one place.
Widget _posterFor(BuildContext context, Object item, String tagPrefix,
    {int? rank, bool showRating = true}) {
  if (item is Movie) {
    final tag = '$tagPrefix-m-${item.id}';
    return PosterCard(
      title: prettyTitle(item.name, year: item.year),
      imageUrl: item.posterUrl,
      artwork: ArtworkQuery(
          name: prettyTitle(item.name, year: item.year),
          year: item.year,
          isSeries: false),
      rating: showRating ? item.rating : null,
      rank: rank,
      heroTag: tag,
      onTap: () => context.push('/movie/${item.id}', extra: tag),
    );
  }
  final series = item as Series;
  final tag = '$tagPrefix-s-${series.id}';
  return PosterCard(
    title: prettyTitle(series.name, year: series.year),
    imageUrl: series.posterUrl,
    artwork: ArtworkQuery(
        name: prettyTitle(series.name, year: series.year),
        year: series.year,
        isSeries: true),
    rating: showRating ? series.rating : null,
    rank: rank,
    heroTag: tag,
    onTap: () => context.push('/series/${series.id}', extra: tag),
  );
}

/// "My List" rail â€” hidden entirely when empty rather than showing a bald
/// heading over nothing.
List<Widget> _myListSlivers(BuildContext context, WidgetRef ref) {
  final items = ref.watch(myListProvider).value ?? const [];
  if (items.isEmpty) return const [];
  return [
    SliverToBoxAdapter(
      child: MediaRail(
        title: 'My List',
        itemCount: items.length,
        itemBuilder: (context, i) =>
            _posterFor(context, items[i], 'mylist'),
      ),
    ),
  ];
}

/// Slivers for the discovery rails. Renders nothing at all while they load or
/// if none resolved â€” an empty gap is better than a spinner for content that is
/// a bonus on top of what Home already shows.
/// The seasonal rail. Renders nothing outside its few weeks of the year, which
/// is what keeps it feeling like an occasion rather than another category row.
List<Widget> _seasonalSlivers(BuildContext context, WidgetRef ref) {
  final season = ref.watch(seasonalRailProvider).value;
  if (season == null || season.items.isEmpty) return const [];
  return [
    SliverToBoxAdapter(
      child: MediaRail(
        title: season.label,
        itemCount: season.items.length,
        itemBuilder: (context, i) {
          final movie = season.items[i];
          final tag = 'season-m-${movie.id}';
          return PosterCard(
            title: prettyTitle(movie.name, year: movie.year),
            imageUrl: movie.posterUrl,
            artwork: ArtworkQuery(
                name: prettyTitle(movie.name, year: movie.year),
                year: movie.year,
                isSeries: false),
            rating: movie.rating,
            heroTag: tag,
            onTap: () => context.push('/movie/${movie.id}', extra: tag),
          );
        },
      ),
    ),
  ];
}

List<Widget> _discoverySlivers(BuildContext context, WidgetRef ref) {
  final rails = ref.watch(discoveryRailsProvider).value ?? const [];
  return [
    for (final rail in rails)
      SliverToBoxAdapter(
        child: MediaRail(
          title: rail.label,
          itemCount: rail.items.length,
          // The numeral needs room, and a rating badge next to a rank is noise.
          height: rail.numbered ? 252 : 236,
          itemBuilder: (context, i) => _posterFor(
            context,
            rail.items[i],
            'disc-${rail.label}',
            rank: rail.numbered ? i + 1 : null,
            showRating: !rail.numbered,
          ),
        ),
      ),
  ];
}

class _ContinueCard extends ConsumerStatefulWidget {
  const _ContinueCard({required this.entry});

  final ContinueEntry entry;

  @override
  ConsumerState<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends ConsumerState<_ContinueCard> {
  /// Focused (D-pad) or hovered (mouse) â€” drives the same pop/ring/glow the
  /// poster cards use, so it is just as obvious which card the remote is on.
  bool _engaged = false;
  ContinueEntry get entry => widget.entry;

  /// Play straight from the card, at the point you stopped.
  ///
  /// For an episode this queues the WHOLE series from that point, not just the
  /// one episode. Resuming used to open the detail page, which built the full
  /// queue on the way through; playing directly skipped that and handed the
  /// player a queue of one, which silently disabled both the Next Episode
  /// button and autoplay-next â€” they only exist when there is a next item.
  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final request = await _buildRequest(ref);
    if (!context.mounted) return;
    await context.push('/player', extra: request);
    ref.invalidate(homeDataProvider);
  }

  Future<PlayerRequest> _buildRequest(WidgetRef ref) async {
    final single = PlayerRequest(
      queue: [
        PlayerItem(
          streamRef: entry.streamRef,
          title: entry.title,
          subtitle: entry.subtitle,
          contentKey: entry.progress.contentKey,
        ),
      ],
      resumeFromSeconds: entry.resumeFromSeconds,
    );
    if (entry.streamRef.type != StreamType.episode) return single;

    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return single;
    final catalog = ref.read(catalogRepositoryProvider);
    final episode =
        await catalog.episodeById(account, entry.streamRef.streamId);
    if (episode == null) return single;
    final episodes = await catalog.episodesOfSeries(account, episode.seriesId);
    final startIndex = episodes.indexWhere((e) => e.id == episode.id);
    // Cache-only: if the series' episodes aren't cached we cannot build a
    // queue, and playing the one episode beats refusing to play at all.
    if (startIndex == -1) return single;

    return PlayerRequest(
      queue: [
        for (final e in episodes)
          PlayerItem(
            streamRef: StreamRef(
              accountId: account.id,
              type: StreamType.episode,
              streamId: e.id,
              containerExt: e.containerExt,
            ),
            title: entry.title,
            subtitle: 'S${e.seasonNumber} Â· E${e.episodeNumber} â€” ${e.title}',
            contentKey: contentKeyFor(
                accountId: account.id,
                type: StreamType.episode,
                id: e.id),
          ),
      ],
      startIndex: startIndex,
      resumeFromSeconds: entry.resumeFromSeconds,
    );
  }

  /// Long-press: the escape hatch. Without a way to remove, something you
  /// abandoned after five minutes sits at the top of Home forever.
  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              // Seeds focus so the sheet is operable by remote the instant it
              // opens (otherwise the first D-pad press is spent finding a row).
              autofocus: true,
              leading: const Icon(Icons.play_arrow),
              title: const Text('Resume'),
              onTap: () {
                Navigator.pop(sheetContext);
                _resume(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(entry.route);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Remove from Continue Watching'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(watchProgressRepositoryProvider)
                    .remove(entry.progress.contentKey);
                ref.invalidate(homeDataProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress;
    final fraction = progress.durationSeconds > 0
        ? (progress.positionSeconds / progress.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    return SizedBox(
      width: 220,
      child: MouseRegion(
        onEnter: (_) => setState(() => _engaged = true),
        onExit: (_) => setState(() => _engaged = false),
        // InkWell, not GestureDetector: a D-pad OK press is an ActivateIntent
        // and GestureDetector ignores it, so on a TV this row took focus and
        // then did nothing.
        child: InkWell(
          // A remote has no long-press, so on a TV the OK button opens the
          // action menu (Resume / Details / Remove â€” all reachable), with
          // Resume auto-focused. Touch keeps tap-to-resume, long-press-for-menu.
          onTap: () => isTelevisionOf(ref)
              ? _showMenu(context, ref)
              : _resume(context, ref),
          onLongPress: () => _showMenu(context, ref),
          borderRadius: BorderRadius.circular(10),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onFocusChange: (focused) {
            setState(() => _engaged = focused);
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
          },
          child: AnimatedScale(
            scale: _engaged ? 1.08 : 1.0,
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Same affordance as PosterCard: a bright ring in the
                // foreground (no layout shift) and an accent glow behind.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _engaged
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _engaged ? AppColors.focusRing : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (entry.imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: entry.imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 720,
                              placeholder: (context, url) => const ColoredBox(
                                  color: AppColors.surfaceElevated),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(
                                      color: AppColors.surfaceElevated),
                            )
                          else
                            const ColoredBox(color: AppColors.surfaceElevated),
                          const Center(
                            child: Icon(Icons.play_circle_outline,
                                size: 40, color: AppColors.textPrimary),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 4,
                              backgroundColor: Colors.transparent,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label),
                if (entry.subtitle != null)
                  Text(entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
