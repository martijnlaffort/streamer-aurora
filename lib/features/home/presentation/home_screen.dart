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
import '../../movies/movies_providers.dart' show isFavoriteProvider;
import '../../player/player_request.dart';
import '../home_providers.dart';
import 'widgets/media_rail.dart';

/// Home (PRD §8.2): rotating featured hero, Continue Watching, Recently
/// Added, and per-category rails — all served from the cached catalog.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);

    return Scaffold(
      body: home.when(
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

class _NoAccount extends StatelessWidget {
  const _NoAccount();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Aurora', style: AppTypography.display),
          const SizedBox(height: 8),
          const Text('Add a playlist to light this screen up.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
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
        // slice — 150k titles on a real line, i.e. minutes of spinner for a
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
          if (data.heroes.isNotEmpty)
            SliverToBoxAdapter(
              child: _FeaturedHero(
                movies: data.heroes,
                // A TV must have something focused or the remote has nowhere to
                // start; the spotlight is the natural place.
                autofocus: isTelevisionOf(ref),
              ),
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
          // Winners). Separate provider — Home never waits on them.
          ..._discoverySlivers(context, ref),
          // The Top Rated rails are gone: they were the panel's own rating with
          // no vote count behind it, which is the exact signal the discovery
          // rails above replaced.
          if (data.recentlyAdded.isNotEmpty)
            SliverToBoxAdapter(
              child: MediaRail(
                title: 'Recently Added',
                itemCount: data.recentlyAdded.length,
                itemBuilder: (context, i) {
                  final movie = data.recentlyAdded[i];
                  final tag = 'recent-m-${movie.id}';
                  return PosterCard(
                    title: prettyTitle(movie.name, year: movie.year),
                    imageUrl: movie.posterUrl,
                    heroTag: tag,
                    onTap: () => context.push('/movie/${movie.id}', extra: tag),
                  );
                },
              ),
            ),
          // Per-category rails moved to the Movies and Series tabs.
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Add/remove the featured hero from My List without leaving Home — the
/// shortcut Netflix and HBO both put on the spotlight.
class _HeroMyListButton extends ConsumerWidget {
  const _HeroMyListButton({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = contentKeyFor(
        accountId: movie.accountId, type: StreamType.movie, id: movie.id);
    final saved = ref.watch(isFavoriteProvider(key)).value ?? false;
    return FilledButton.tonalIcon(
      onPressed: () async {
        await ref.read(favoritesRepositoryProvider).toggle(key);
        ref.invalidate(isFavoriteProvider(key));
        ref.invalidate(myListProvider);
      },
      icon: Icon(saved ? Icons.check : Icons.add, size: 18),
      label: Text(saved ? 'In My List' : 'My List'),
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
    rating: showRating ? series.rating : null,
    rank: rank,
    heroTag: tag,
    onTap: () => context.push('/series/${series.id}', extra: tag),
  );
}

/// "My List" rail — hidden entirely when empty rather than showing a bald
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
/// if none resolved — an empty gap is better than a spinner for content that is
/// a bonus on top of what Home already shows.
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

/// Rotating featured hero (PRD §8.2/§10): gentle cross-fades through the
/// newest additions every few seconds.
class _FeaturedHero extends StatefulWidget {
  const _FeaturedHero({required this.movies, this.autofocus = false});

  final List<Movie> movies;
  final bool autofocus;

  @override
  State<_FeaturedHero> createState() => _FeaturedHeroState();
}

class _FeaturedHeroState extends State<_FeaturedHero> {
  int _index = 0;
  Timer? _timer;

  /// Auto-rotation stops once you engage with the hero. Without this the title
  /// changes under your thumb while you are reading it or reaching for a
  /// button, which turns the spotlight into a hazard.
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    if (widget.movies.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted && !_paused) {
          setState(() => _index = (_index + 1) % widget.movies.length);
        }
      });
    }
  }

  void _pause() {
    if (!_paused && mounted) setState(() => _paused = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movies[_index];
    return MouseRegion(
      onEnter: (_) => _pause(),
      child: InkWell(
        // InkWell so the remote's OK button activates it; GestureDetector
        // takes focus on a TV and then ignores the press.
        onTap: () {
          _pause();
          context.push('/movie/${movie.id}');
        },
        onFocusChange: (focused) {
          if (focused) _pause();
        },
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: SizedBox(
          height: 430,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The poster renders immediately from the cached row; the wider
            // backdrop is fetched off Home's critical path and cross-fades in
            // when it arrives (see heroBackdropProvider).
            Consumer(
              builder: (context, ref, _) {
                // Both "still loading" and "no backdrop" collapse to null here,
                // which is what we want: keep showing the poster.
                final backdrop = movie.backdropUrl ??
                    ref.watch(heroBackdropProvider(movie.id)).value;
                final image = backdrop ?? movie.posterUrl;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: image != null
                      ? CachedNetworkImage(
                          key: ValueKey('${movie.id}-$image'),
                          imageUrl: image,
                          fit: BoxFit.cover,
                          // Full-width hero backdrop — decode at ~1080px, not
                          // the source's full resolution (often 1920+).
                          memCacheWidth: 1080,
                          placeholder: (context, url) =>
                              const ColoredBox(color: AppColors.surfaceElevated),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(color: AppColors.surfaceElevated),
                        )
                      : ColoredBox(
                          key: ValueKey('empty-${movie.id}'),
                          color: AppColors.surfaceElevated),
                );
              },
            ),
            const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.scrim)),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECENTLY ADDED',
                      style: AppTypography.label
                          .copyWith(color: AppColors.accentAlt)),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      prettyTitle(movie.name, year: movie.year),
                      key: ValueKey(movie.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display.copyWith(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wrap, not Row: the TV shell's navigation rail takes a slice
                  // of the width, and two buttons plus the page dots overflowed
                  // a Row outright. Wrap moves the dots to their own line when
                  // the space is not there instead of clipping.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        autofocus: widget.autofocus,
                        onPressed: () => context.push('/movie/${movie.id}'),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                      ),
                      _HeroMyListButton(movie: movie),
                      if (widget.movies.length > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, _) in widget.movies.indexed)
                              Container(
                                width: i == _index ? 16 : 6,
                                height: 6,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: i == _index
                                      ? AppColors.accent
                                      : Colors.white30,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.entry});

  final ContinueEntry entry;

  /// Play straight from the card, at the point you stopped.
  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    await context.push(
      '/player',
      extra: PlayerRequest(
        queue: [
          PlayerItem(
            streamRef: entry.streamRef,
            title: entry.title,
            subtitle: entry.subtitle,
            contentKey: entry.progress.contentKey,
          ),
        ],
        resumeFromSeconds: entry.resumeFromSeconds,
      ),
    );
    ref.invalidate(homeDataProvider);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = entry.progress;
    final fraction = progress.durationSeconds > 0
        ? (progress.positionSeconds / progress.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    return SizedBox(
      width: 220,
      // InkWell, not GestureDetector: a D-pad OK press is an ActivateIntent
      // and GestureDetector ignores it, so on a TV this row took focus and
      // then did nothing.
      child: InkWell(
        onTap: () => _resume(context, ref),
        onLongPress: () => _showMenu(context, ref),
        borderRadius: BorderRadius.circular(10),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
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
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.surfaceElevated),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: AppColors.surfaceElevated),
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
    );
  }
}
