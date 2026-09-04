import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/focus_highlight.dart';
import '../../../core/widgets/my_list_button.dart';
import '../../../data/providers.dart';
import '../../../core/matching/title_label.dart';
import '../../../domain/models/models.dart';
import '../../home/home_providers.dart';
import '../../movies/movies_providers.dart';
import '../../player/player_request.dart';
import '../series_providers.dart';

/// Series detail (PRD §8.4/§8.7): season selector, episode list with
/// per-episode progress, primary action = next unwatched episode.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.seriesId, this.heroTag});

  final String seriesId;

  /// Shared-element tag from the originating poster card (PRD §10).
  final String? heroTag;

  @override
  ConsumerState<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int? _selectedSeason;

  String _episodeKey(String accountId, Episode e) => contentKeyFor(
      accountId: accountId, type: StreamType.episode, id: e.id);

  Future<void> _play(
    SeriesDetail detail,
    String accountId,
    int episodeIndex, {
    int? resumeFrom,
  }) async {
    final queue = [
      for (final e in detail.episodes)
        PlayerItem(
          streamRef: StreamRef(
            accountId: accountId,
            type: StreamType.episode,
            streamId: e.id,
            containerExt: e.containerExt,
          ),
          title: prettyTitle(detail.series.name, year: detail.series.year),
          subtitle: episodeLabel(
            season: e.seasonNumber,
            episode: e.episodeNumber,
            title: e.title,
            seriesName: detail.series.name,
          ),
          contentKey: _episodeKey(accountId, e),
          seriesId: detail.series.id,
        ),
    ];
    await context.push('/player',
        extra: PlayerRequest(
          queue: queue,
          startIndex: episodeIndex,
          resumeFromSeconds: resumeFrom,
        ));
    ref.invalidate(seriesProgressProvider(widget.seriesId));
    ref.invalidate(progressProvider);
    ref.invalidate(homeDataProvider);
  }

  Widget _headerImage(String? image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            placeholder: (context, url) =>
                ColoredBox(color: AppColors.surfaceElevated),
            errorWidget: (context, url, error) =>
                ColoredBox(color: AppColors.surfaceElevated),
          )
        else
          ColoredBox(color: AppColors.surfaceElevated),
        DecoratedBox(decoration: BoxDecoration(gradient: AppColors.scrim)),
      ],
    );
  }

  /// First episode that isn't completed; partially-watched counts (that's
  /// the one to continue). Falls back to the first episode.
  (int, WatchProgress?) _nextUp(
      SeriesDetail detail, String accountId, Map<String, WatchProgress> progress) {
    for (final (i, e) in detail.episodes.indexed) {
      final p = progress[_episodeKey(accountId, e)];
      if (p == null || !p.completed) return (i, p);
    }
    return (0, null);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(seriesDetailProvider(widget.seriesId));
    final progressAsync = ref.watch(seriesProgressProvider(widget.seriesId));
    final accountAsync = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(),
      extendBodyBehindAppBar: true,
      body: detailAsync.when(
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(seriesDetailProvider(widget.seriesId))),
        data: (detail) {
          // Wait for the account too: reading `.value` while it is still
          // loading briefly returned null and flashed "Not found" before the
          // real content appeared.
          if (accountAsync.isLoading && !accountAsync.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          final account = accountAsync.value;
          if (detail == null || account == null) {
            return const Center(child: Text('Not found in the catalog.'));
          }
          final progress = progressAsync.value ?? const <String, WatchProgress>{};
          final seasons = detail.seasons;
          final selectedSeason =
              _selectedSeason ?? seasons.firstOrNull?.seasonNumber ?? 1;
          final episodes = detail.episodesOfSeason(selectedSeason);
          // A series can arrive with no episodes at all — a stub entry on the
          // panel, or a season list the panel holds no files for. Guard every
          // path that indexes into episodes so the screen degrades to an empty
          // state instead of crashing with a RangeError.
          final hasEpisodes = detail.episodes.isNotEmpty;
          final (nextIndex, nextProgress) = hasEpisodes
              ? _nextUp(detail, account.id, progress)
              : (0, null);
          final next = hasEpisodes ? detail.episodes[nextIndex] : null;
          final resume = hasEpisodes &&
              ref
                  .read(watchProgressRepositoryProvider)
                  .shouldOfferResume(nextProgress);

          final series = detail.series;
          final image = series.backdropUrl ?? series.posterUrl;
          final meta = [
            if (series.year != null) '${series.year}',
            if (series.genre != null) series.genre!,
            '${detail.seasons.length} season${detail.seasons.length == 1 ? '' : 's'}',
            if (series.rating != null) '★ ${series.rating!.toStringAsFixed(1)}',
          ].join('  ·  ');

          // Proportional, not fixed: a television reports a far shorter logical
          // height than a phone, so a fixed 280px backdrop ate a third of the
          // screen there. The wider side padding is deliberate on a TV — sets
          // crop the outer few percent (overscan), and a 10-foot layout wants
          // its text well clear of the edge.
          final tv = isTelevisionOf(ref);
          final headerHeight =
              (MediaQuery.sizeOf(context).height * (tv ? 0.26 : 0.30))
                  .clamp(140.0, 280.0);
          final sidePad = tv ? 48.0 : 24.0;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: headerHeight,
                child: widget.heroTag != null
                    ? Hero(
                        tag: widget.heroTag!,
                        child: _headerImage(image),
                      )
                    : _headerImage(image),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(sidePad, 24, sidePad, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prettyTitle(series.name, year: series.year),
                        style: AppTypography.display.copyWith(fontSize: 25)),
                    const SizedBox(height: 10),
                    Text(meta,
                        style: TextStyle(color: AppColors.textSecondary)),
                    if (series.plot != null) ...[
                      const SizedBox(height: 16),
                      Text(series.plot!,
                          style: AppTypography.body.copyWith(height: 1.5)),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (hasEpisodes) ...[
                          // FocusHighlight, not Material's focus overlay: that
                          // overlay is invisible on this near-black theme from a
                          // sofa, which is why the page felt cursor-less.
                          Expanded(
                            child: FocusHighlight(
                              borderRadius: 20,
                              scale: 1.0,
                              child: FilledButton.icon(
                                // Seed focus on a TV so the page opens with a
                                // visible cursor.
                                autofocus: tv,
                                onPressed: () => _play(
                                    detail, account.id, nextIndex,
                                    resumeFrom: resume
                                        ? nextProgress!.positionSeconds
                                        : null),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  resume
                                      ? 'Resume S${next!.seasonNumber} E${next.episodeNumber} '
                                          'from ${formatSeconds(nextProgress!.positionSeconds)}'
                                      : 'Play S${next!.seasonNumber} E${next.episodeNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        FocusHighlight(
                          borderRadius: 20,
                          child: MyListButton(
                            contentKey: contentKeyForSeries(
                                accountId: account.id, id: series.id),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (seasons.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: sidePad - 4),
                    itemCount: seasons.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final season = seasons[i];
                      final selected = season.seasonNumber == selectedSeason;
                      // FocusHighlight: gives the chip a ring the remote can see
                      // (the season selector is the control the D-pad must pass
                      // through between Play and the episode list), and scrolls
                      // the chip itself into view — `ensureVisible` with the
                      // itemBuilder's context would target the ListView's sliver
                      // element instead and jump to a fixed offset.
                      return FocusHighlight(
                        borderRadius: 20,
                        scale: 1.0,
                        ensureVisible: true,
                        child: ChoiceChip(
                          label: Text(
                              season.name ?? 'Season ${season.seasonNumber}'),
                          selected: selected,
                          onSelected: (_) => setState(
                              () => _selectedSeason = season.seasonNumber),
                          selectedColor:
                              AppColors.accent.withValues(alpha: 0.28),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (!hasEpisodes)
                Padding(
                  padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 0),
                  child: Text(
                      'No episodes available for this series yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              for (final episode in episodes)
                _EpisodeTile(
                  episode: episode,
                  sidePad: sidePad,
                  seriesName: series.name,
                  progress: progress[_episodeKey(account.id, episode)],
                  fallbackImage: series.posterUrl,
                  onTap: () {
                    final index = detail.episodes.indexOf(episode);
                    final p = progress[_episodeKey(account.id, episode)];
                    final offerResume = ref
                        .read(watchProgressRepositoryProvider)
                        .shouldOfferResume(p);
                    _play(detail, account.id, index,
                        resumeFrom: offerResume ? p!.positionSeconds : null);
                  },
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.progress,
    required this.onTap,
    required this.sidePad,
    required this.seriesName,
    this.fallbackImage,
  });

  final Episode episode;
  final WatchProgress? progress;
  final String? fallbackImage;
  final VoidCallback onTap;

  /// Used only to strip the series name back out of the episode's own title,
  /// which panels routinely repeat there.
  final String seriesName;

  /// Matches the page's side padding so the rows line up with the title above.
  final double sidePad;

  @override
  Widget build(BuildContext context) {
    final image = episode.stillUrl ?? fallbackImage;
    final fraction = progress != null && progress!.durationSeconds > 0
        ? (progress!.positionSeconds / progress!.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    // Wrapped so the D-pad shows which episode it is on, and scrolled into view
    // so focus can't walk off the bottom of a long season.
    // Inset by the page's side padding so the focus ring sits inside the
    // overscan margin (a full-bleed ring would be drawn at x=0, i.e. in the
    // part of the picture a real TV crops) and the rows line up with the title.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sidePad - 8),
      child: FocusHighlight(
        scale: 1.0,
        // Re-centres the focused row. The framework's own scroll-into-view puts
        // it flush against the bottom edge, which overscan then clips.
        ensureVisible: true,
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onTap: onTap,
      leading: SizedBox(
        width: 96,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    memCacheWidth: 720,
                    placeholder: (context, url) =>
                        ColoredBox(color: AppColors.surfaceElevated),
                    errorWidget: (context, url, error) =>
                        ColoredBox(color: AppColors.surfaceElevated),
                  )
                else
                  ColoredBox(color: AppColors.surfaceElevated),
                if (fraction > 0 && !(progress?.completed ?? false))
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
          switch (prettyEpisodeTitle(episode.title, seriesName: seriesName)) {
            '' => 'Episode ${episode.episodeNumber}',
            final name => 'E${episode.episodeNumber} · $name',
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: episode.durationSeconds != null
          ? Text('${(episode.durationSeconds! / 60).ceil()} min',
              style: TextStyle(color: AppColors.textSecondary))
          : null,
      trailing: (progress?.completed ?? false)
          ? Icon(Icons.check_circle, color: AppColors.accentAlt, size: 20)
          : Icon(Icons.play_circle_outline,
              color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}
