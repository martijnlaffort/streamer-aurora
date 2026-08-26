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
import '../../player/player_request.dart';
import '../movies_providers.dart';

/// Cache-first movie lookup, enriched from the source when reachable.
final movieByIdProvider =
    FutureProvider.family<Movie?, String>((ref, movieId) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final catalog = ref.watch(catalogRepositoryProvider);
  try {
    return await catalog.movieDetail(account, movieId);
  } on Exception {
    return catalog.movieById(account, movieId);
  }
});

/// Movie detail (PRD §8.7): backdrop, meta, plot, cast, context-aware
/// Play/Resume with Start over, favorite toggle.
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.heroTag});

  final String movieId;

  /// Shared-element tag from the originating poster card (PRD §10).
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movie = ref.watch(movieByIdProvider(movieId));

    return Scaffold(
      appBar: AppBar(),
      extendBodyBehindAppBar: true,
      body: movie.when(
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(movieByIdProvider(movieId))),
        data: (m) => m == null
            ? const Center(child: Text('Not found in the catalog.'))
            : _MovieDetail(movie: m, heroTag: heroTag),
      ),
    );
  }
}

class _MovieDetail extends ConsumerWidget {
  const _MovieDetail({required this.movie, this.heroTag});

  final Movie movie;
  final String? heroTag;

  String get _contentKey => contentKeyFor(
      accountId: movie.accountId, type: StreamType.movie, id: movie.id);

  Widget _maybeHero(Widget child) =>
      heroTag != null ? Hero(tag: heroTag!, child: child) : child;

  Future<void> _play(BuildContext context, WidgetRef ref,
      {int? resumeFrom}) async {
    final request = PlayerRequest(
      queue: [
        PlayerItem(
          streamRef: StreamRef(
            accountId: movie.accountId,
            type: StreamType.movie,
            streamId: movie.id,
            containerExt: movie.containerExt,
          ),
          title: prettyTitle(movie.name, year: movie.year),
          contentKey: _contentKey,
        ),
      ],
      resumeFromSeconds: resumeFrom,
    );
    await context.push('/player', extra: request);
    // Progress changed while we were away — refresh anything showing it.
    ref.invalidate(progressProvider(_contentKey));
    ref.invalidate(homeDataProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider(_contentKey)).value;
    final offerResume = ref
        .read(watchProgressRepositoryProvider)
        .shouldOfferResume(progress);

    final image = movie.backdropUrl ?? movie.posterUrl;
    final meta = [
      if (movie.year != null) '${movie.year}',
      if (movie.genre != null) movie.genre!,
      if (movie.durationSeconds != null) '${movie.durationSeconds! ~/ 60} min',
      if (movie.rating != null) '★ ${movie.rating!.toStringAsFixed(1)}',
    ].join('  ·  ');

    // Sizing is proportional rather than fixed. A television reports a much
    // shorter logical height than a phone, so the old fixed 300px backdrop ate
    // well over a third of the screen there — which is what made the detail
    // page feel oversized. The generous side padding is deliberate on a TV:
    // real sets crop the outer few percent (overscan), and a 10-foot layout
    // wants its text away from the edge anyway.
    final tv = isTelevisionOf(ref);
    final headerHeight =
        (MediaQuery.sizeOf(context).height * (tv ? 0.26 : 0.30))
            .clamp(140.0, 300.0);
    final sidePad = tv ? 48.0 : 24.0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: headerHeight,
          child: _maybeHero(Stack(
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
              DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.scrim)),
            ],
          )),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(sidePad, 24, sidePad, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prettyTitle(movie.name, year: movie.year),
                  style: AppTypography.display.copyWith(fontSize: 25)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(meta,
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  // FocusHighlight, not the Material focus overlay: on this
                  // near-black theme that overlay is invisible from a sofa,
                  // which is why the detail page felt like it had no cursor.
                  Expanded(
                    child: FocusHighlight(
                      borderRadius: 20,
                      scale: 1.0,
                      child: FilledButton.icon(
                        // Seed focus on a TV so the page has a visible cursor the
                        // moment it opens, instead of the unhighlighted AppBar
                        // back button.
                        autofocus: tv,
                        onPressed: () => _play(context, ref,
                            resumeFrom:
                                offerResume ? progress!.positionSeconds : null),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          offerResume
                              ? 'Resume from ${formatSeconds(progress!.positionSeconds)}'
                              : 'Play',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FocusHighlight(borderRadius: 20, child: MyListButton(contentKey: _contentKey)),
                ],
              ),
              if (offerResume) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FocusHighlight(
                    borderRadius: 20,
                    child: TextButton.icon(
                      onPressed: () => _play(context, ref),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Start over'),
                    ),
                  ),
                ),
              ],
              if (movie.plot != null) ...[
                const SizedBox(height: 28),
                Text(movie.plot!,
                    style: AppTypography.body.copyWith(height: 1.5)),
              ],
              if (movie.cast != null) ...[
                const SizedBox(height: 24),
                Text('Cast', style: AppTypography.title.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(movie.cast!,
                    style: TextStyle(
                        color: AppColors.textSecondary, height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
