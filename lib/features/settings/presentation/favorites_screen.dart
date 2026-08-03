import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../player/player_request.dart';

/// Favorites resolved against the cached catalog (PRD §8.11), aggregating
/// movies, series, and live channels.
final favoritesViewProvider = FutureProvider<
    ({List<Movie> movies, List<Series> series, List<Channel> channels})>(
    (ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) {
    return (movies: <Movie>[], series: <Series>[], channels: <Channel>[]);
  }
  final catalog = ref.watch(catalogRepositoryProvider);
  final favorites = await ref.watch(favoritesRepositoryProvider).all();

  final movies = <Movie>[];
  final series = <Series>[];
  final channels = <Channel>[];
  for (final (contentKey, _) in favorites) {
    final key = parseContentKey(contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type == StreamType.movie.name) {
      final movie = await catalog.movieById(account, key.id);
      if (movie != null) movies.add(movie);
    } else if (key.type == 'series') {
      final s = await catalog.seriesById(account, key.id);
      if (s != null) series.add(s);
    } else if (key.type == StreamType.live.name) {
      final c = await catalog.channelById(account, key.id);
      if (c != null) channels.add(c);
    }
  }
  return (movies: movies, series: series, channels: channels);
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  void _playChannel(BuildContext context, Channel channel) {
    context.push(
      '/player',
      extra: PlayerRequest(
        queue: [
          PlayerItem(
            streamRef: StreamRef(
              accountId: channel.accountId,
              type: StreamType.live,
              streamId: channel.id,
            ),
            title: channel.name,
            contentKey: contentKeyFor(
                accountId: channel.accountId,
                type: StreamType.live,
                id: channel.id),
            isLive: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesViewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (data) {
          if (data.movies.isEmpty &&
              data.series.isEmpty &&
              data.channels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No favorites yet.'),
                  Text('Tap the heart on any detail page or channel.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          final posterItems = [
            for (final m in data.movies)
              (m.name, m.posterUrl, '/movie/${m.id}'),
            for (final s in data.series)
              (s.name, s.posterUrl, '/series/${s.id}'),
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (data.channels.isNotEmpty) ...[
                const _SectionHeader('Channels'),
                for (final channel in data.channels)
                  ListTile(
                    leading: _ChannelLogo(url: channel.logoUrl),
                    title: Text(channel.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.play_circle_outline,
                        color: AppColors.textSecondary),
                    onTap: () => _playChannel(context, channel),
                  ),
              ],
              if (posterItems.isNotEmpty) ...[
                if (data.channels.isNotEmpty)
                  const _SectionHeader('Movies & Series'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: posterItems.length,
                  itemBuilder: (context, i) {
                    final (title, image, route) = posterItems[i];
                    return PosterCard(
                      title: title,
                      imageUrl: image,
                      onTap: () => context.push(route),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: AppTypography.title),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              memCacheWidth: 200,
              errorWidget: (context, u, e) =>
                  const Icon(Icons.live_tv, color: AppColors.textSecondary),
            )
          : const Icon(Icons.live_tv, color: AppColors.textSecondary),
    );
  }
}
