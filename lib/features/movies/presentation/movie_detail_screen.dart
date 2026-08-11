import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/my_list_button.dart';
import '../../../data/providers.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error))),
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
          title: movie.name,
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 300,
          child: _maybeHero(Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  placeholder: (context, url) =>
                      const ColoredBox(color: AppColors.surfaceElevated),
                  errorWidget: (context, url, error) =>
                      const ColoredBox(color: AppColors.surfaceElevated),
                )
              else
                const ColoredBox(color: AppColors.surfaceElevated),
              const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.scrim)),
            ],
          )),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.name,
                  style: AppTypography.display.copyWith(fontSize: 28)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meta,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _play(context, ref,
                          resumeFrom:
                              offerResume ? progress!.positionSeconds : null),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(offerResume
                          ? 'Resume from ${formatSeconds(progress!.positionSeconds)}'
                          : 'Play'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MyListButton(contentKey: _contentKey),
                ],
              ),
              if (offerResume) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _play(context, ref),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Start over'),
                ),
              ],
              if (movie.plot != null) ...[
                const SizedBox(height: 20),
                Text(movie.plot!, style: AppTypography.body),
              ],
              if (movie.cast != null) ...[
                const SizedBox(height: 16),
                Text('Cast', style: AppTypography.title.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(movie.cast!,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
