import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/db/app_database.dart' show CatalogKind;
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../home_providers.dart';
import 'widgets/media_rail.dart';

/// Home (PRD §8.2): featured hero, Continue Watching, Recently Added, and
/// per-category rails — all served from the cached catalog.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);

    return Scaffold(
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your catalog: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
          ),
        ),
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
          const Text('Aurora', style: AppTypography.display),
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
        final account = await ref.read(activeAccountProvider.future);
        if (account == null) return;
        await ref
            .read(catalogRepositoryProvider)
            .refreshCatalog(account, kinds: {CatalogKind.vod});
        ref.invalidate(homeDataProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (data.hero != null)
            SliverToBoxAdapter(child: _Hero(movie: data.hero!)),
          if (data.continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: MediaRail(
                title: 'Continue Watching',
                height: 172,
                itemCount: data.continueWatching.length,
                itemBuilder: (context, i) {
                  final (progress, movie) = data.continueWatching[i];
                  return _ContinueCard(progress: progress, movie: movie);
                },
              ),
            ),
          if (data.recentlyAdded.isNotEmpty)
            SliverToBoxAdapter(
              child: MediaRail(
                title: 'Recently Added',
                itemCount: data.recentlyAdded.length,
                itemBuilder: (context, i) {
                  final movie = data.recentlyAdded[i];
                  return PosterCard(
                    title: movie.name,
                    imageUrl: movie.posterUrl,
                    onTap: () => context.push('/movie/${movie.id}'),
                  );
                },
              ),
            ),
          for (final (category, movies) in data.categoryRails)
            SliverToBoxAdapter(
              child: MediaRail(
                title: category.name,
                itemCount: movies.length,
                itemBuilder: (context, i) {
                  final movie = movies[i];
                  return PosterCard(
                    title: movie.name,
                    imageUrl: movie.posterUrl,
                    onTap: () => context.push('/movie/${movie.id}'),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final image = movie.backdropUrl ?? movie.posterUrl;
    return GestureDetector(
      onTap: () => context.push('/movie/${movie.id}'),
      child: SizedBox(
        height: 420,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: AppColors.surfaceElevated),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: AppColors.surfaceElevated),
              )
            else
              const ColoredBox(color: AppColors.surfaceElevated),
            // Content stays legible over any artwork (PRD §10).
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
                  Text(movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display.copyWith(fontSize: 32)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/movie/${movie.id}'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.progress, required this.movie});

  final WatchProgress progress;
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final image = movie.backdropUrl ?? movie.posterUrl;
    final fraction = progress.durationSeconds > 0
        ? (progress.positionSeconds / progress.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    return SizedBox(
      width: 220,
      child: GestureDetector(
        onTap: () => context.push('/movie/${movie.id}'),
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
                    if (image != null)
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
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
            Text(movie.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label),
          ],
        ),
      ),
    );
  }
}
