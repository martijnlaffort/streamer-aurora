import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_chips.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../movies/movies_providers.dart' show isFavoriteProvider;
import '../../player/player_request.dart';
import '../live_providers.dart';

/// Live TV (PRD §8.5): channel list with category filter and favorites,
/// now/next where the source provides EPG, tap to play.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(liveCategoriesProvider);
    final channels = ref.watch(channelsListProvider(_categoryId));
    final hasEpg = ref.watch(hasEpgProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          if (hasEpg)
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'TV Guide',
              onPressed: () => context.push('/guide'),
            ),
        ],
      ),
      body: Column(
        children: [
          categories.when(
            data: (list) => list.isEmpty
                ? const SizedBox(height: 4)
                : CategoryChips(
                    categories: list,
                    selectedId: _categoryId,
                    onSelected: (id) => setState(() => _categoryId = id),
                  ),
            loading: () => const SizedBox(height: 44),
            error: (e, _) => const SizedBox(height: 44),
          ),
          Expanded(
            child: channels.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e',
                      style: const TextStyle(color: AppColors.error))),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('No channels in this playlist.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ChannelTile(channel: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel});

  final Channel channel;

  String get _contentKey => contentKeyFor(
      accountId: channel.accountId, type: StreamType.live, id: channel.id);

  void _play(BuildContext context, {String? nowTitle}) {
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
            subtitle: nowTitle != null ? 'Now: $nowTitle' : null,
            contentKey: _contentKey,
            isLive: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = ref.watch(nowNextProvider(channel)).value ?? const [];
    final now = nowNext.isNotEmpty ? nowNext.first : null;
    final next = nowNext.length > 1 ? nowNext[1] : null;
    final favorite = ref.watch(isFavoriteProvider(_contentKey)).value ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => _play(context, nowTitle: now?.title),
      leading: _Logo(url: channel.logoUrl),
      title: Text(channel.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: now == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('Now: ${now.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.accentAlt)),
                if (next != null)
                  Text('Next: ${next.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                _ProgrammeProgress(entry: now),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color:
                    favorite ? AppColors.accent : AppColors.textSecondary),
            onPressed: () async {
              await ref.read(favoritesRepositoryProvider).toggle(_contentKey);
              ref.invalidate(isFavoriteProvider(_contentKey));
            },
          ),
          const Icon(Icons.play_circle_outline,
              color: AppColors.textSecondary, size: 22),
        ],
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
              errorWidget: (context, u, e) => const Icon(Icons.live_tv,
                  color: AppColors.textSecondary),
            )
          : const Icon(Icons.live_tv, color: AppColors.textSecondary),
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
