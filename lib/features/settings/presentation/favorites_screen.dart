import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../core/matching/title_label.dart';
import '../../../domain/models/models.dart';
import '../../player/player_request.dart';

/// Favorites resolved against the cached catalog (PRD §8.11), aggregating
/// movies, series, and live channels.
///
/// Also reports what could NOT be resolved. A saved item is a content key
/// (`account:type:id`) pointing at a catalogue row, and two things make that
/// row unreachable: the key belongs to a *different account* (re-adding a
/// playlist mints a new account id, which orphans everything saved under the
/// old one), or the row is no longer cached (the panel dropped the title, or
/// moved it to a category that has since been re-fetched without it).
///
/// Both used to fail silently — saved items just vanished from My List with no
/// explanation. Counting them turns that into something the UI can say out loud,
/// and distinguishes the two causes.
typedef FavoritesView = ({
  List<Movie> movies,
  List<Series> series,
  List<Channel> channels,
  int otherAccount,
  int missingFromCatalog,
});

final favoritesViewProvider = FutureProvider<FavoritesView>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) {
    return (
      movies: <Movie>[],
      series: <Series>[],
      channels: <Channel>[],
      otherAccount: 0,
      missingFromCatalog: 0,
    );
  }
  final catalog = ref.watch(catalogRepositoryProvider);
  final favorites = await ref.watch(favoritesRepositoryProvider).all();

  final movies = <Movie>[];
  final series = <Series>[];
  final channels = <Channel>[];
  var otherAccount = 0;
  var missingFromCatalog = 0;
  for (final (contentKey, _) in favorites) {
    final key = parseContentKey(contentKey);
    if (key == null) continue;
    if (key.accountId != account.id) {
      otherAccount++;
      continue;
    }
    if (key.type == StreamType.movie.name) {
      final movie = await catalog.movieById(account, key.id);
      if (movie != null) {
        movies.add(movie);
      } else {
        missingFromCatalog++;
      }
    } else if (key.type == seriesContentType) {
      final s = await catalog.seriesById(account, key.id);
      if (s != null) {
        series.add(s);
      } else {
        missingFromCatalog++;
      }
    } else if (key.type == StreamType.live.name) {
      final c = await catalog.channelById(account, key.id);
      if (c != null) {
        channels.add(c);
      } else {
        missingFromCatalog++;
      }
    } else if (key.type == StreamType.episode.name) {
      // Older saves marked a show by favouriting one of its episodes.
      final episode = await catalog.episodeById(account, key.id);
      final s = episode == null
          ? null
          : await catalog.seriesById(account, episode.seriesId);
      if (s != null && !series.any((existing) => existing.id == s.id)) {
        series.add(s);
      } else if (s == null) {
        missingFromCatalog++;
      }
    }
  }
  return (
    movies: movies,
    series: series,
    channels: channels,
    otherAccount: otherAccount,
    missingFromCatalog: missingFromCatalog,
  );
});

/// Explains saved items that could not be shown, instead of dropping them
/// silently. Renders nothing when everything resolved.
class _UnresolvedNote extends StatelessWidget {
  const _UnresolvedNote({required this.otherAccount, required this.missing});

  final int otherAccount;
  final int missing;

  @override
  Widget build(BuildContext context) {
    if (otherAccount == 0 && missing == 0) return const SizedBox.shrink();
    final lines = [
      if (otherAccount > 0)
        '$otherAccount saved ${otherAccount == 1 ? 'item was' : 'items were'} '
            'added under a different account. Re-adding a playlist creates a '
            'new account, which leaves earlier saves attached to the old one.',
      if (missing > 0)
        '$missing saved ${missing == 1 ? 'item is' : 'items are'} no longer in '
            'your playlist, so there is nothing to show for them.',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lines.join('\n\n'),
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

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
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesViewProvider)),
        data: (data) {
          final unresolved = _UnresolvedNote(
              otherAccount: data.otherAccount,
              missing: data.missingFromCatalog);
          if (data.movies.isEmpty &&
              data.series.isEmpty &&
              data.channels.isEmpty) {
            if (data.otherAccount > 0 || data.missingFromCatalog > 0) {
              return ListView(children: [unresolved]);
            }
            return const EmptyView(
              icon: Icons.bookmark_border,
              title: 'Nothing saved yet',
              message: 'Open any film or series and tap “My List”, or tap the '
                  'heart on a live channel. Saved items appear on Home.',
            );
          }
          final posterItems = <(String, String?, String, ArtworkQuery)>[
            for (final m in data.movies)
              (
                prettyTitle(m.name, year: m.year),
                m.posterUrl,
                '/movie/${m.id}',
                ArtworkQuery(
                    name: prettyTitle(m.name, year: m.year),
                    year: m.year,
                    isSeries: false),
              ),
            for (final s in data.series)
              (
                prettyTitle(s.name, year: s.year),
                s.posterUrl,
                '/series/${s.id}',
                ArtworkQuery(
                    name: prettyTitle(s.name, year: s.year),
                    year: s.year,
                    isSeries: true),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              unresolved,
              if (data.channels.isNotEmpty) ...[
                const _SectionHeader('Channels'),
                for (final channel in data.channels)
                  ListTile(
                    leading: _ChannelLogo(url: channel.logoUrl),
                    title: Text(channel.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(Icons.play_circle_outline,
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
                    final (title, image, route, artwork) = posterItems[i];
                    return PosterCard(
                      title: title,
                      imageUrl: image,
                      artwork: artwork,
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
                  Icon(Icons.live_tv, color: AppColors.textSecondary),
            )
          : Icon(Icons.live_tv, color: AppColors.textSecondary),
    );
  }
}
