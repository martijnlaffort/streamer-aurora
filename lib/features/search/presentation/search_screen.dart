import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../player/player_request.dart';

/// Unified instant search over the cached catalog (PRD §8.6): debounced,
/// no network round-trips — movies, series, and live channels.
final searchResultsProvider = FutureProvider.family<
    ({List<Movie> movies, List<Series> series, List<Channel> channels}),
    String>((ref, query) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null || query.trim().length < 2) {
    return (movies: <Movie>[], series: <Series>[], channels: <Channel>[]);
  }
  final catalog = ref.watch(catalogRepositoryProvider);
  final q = query.trim();
  return (
    movies: await catalog.searchMovies(account, q),
    series: await catalog.searchSeries(account, q),
    channels: await catalog.searchChannels(account, q),
  );
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Re-run a tapped recent search.
  void _runQuery(String q) {
    _debounce?.cancel();
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q);
  }

  /// Persist the current query as a recent search (on submit or result tap).
  Future<void> _record() async {
    final q = _query.trim();
    if (q.length < 2) return;
    await ref.read(searchHistoryRepositoryProvider).record(q);
    ref.invalidate(recentSearchesProvider);
  }

  void _playChannel(Channel channel) {
    _record();
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
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (_) => _record(),
          textInputAction: TextInputAction.search,
          autofocus: false,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Search movies, series, channels…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (data) {
          if (_query.trim().length < 2) {
            return _RecentSearches(
              onTapQuery: _runQuery,
              onRemove: (q) async {
                await ref.read(searchHistoryRepositoryProvider).remove(q);
                ref.invalidate(recentSearchesProvider);
              },
              onClear: () async {
                await ref.read(searchHistoryRepositoryProvider).clear();
                ref.invalidate(recentSearchesProvider);
              },
            );
          }
          if (data.movies.isEmpty &&
              data.series.isEmpty &&
              data.channels.isEmpty) {
            return Center(
              child: Text('Nothing found for “${_query.trim()}”.',
                  style: const TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView(
            children: [
              if (data.channels.isNotEmpty) ...[
                const _SectionHeader('Channels'),
                for (final channel in data.channels)
                  _ResultTile(
                    title: channel.name,
                    imageUrl: channel.logoUrl,
                    contain: true,
                    onTap: () => _playChannel(channel),
                  ),
              ],
              if (data.movies.isNotEmpty) ...[
                const _SectionHeader('Movies'),
                for (final movie in data.movies)
                  _ResultTile(
                    title: movie.name,
                    imageUrl: movie.posterUrl,
                    subtitle: [
                      if (movie.year != null) '${movie.year}',
                      if (movie.genre != null) movie.genre!,
                    ].join(' · '),
                    onTap: () {
                      _record();
                      context.push('/movie/${movie.id}');
                    },
                  ),
              ],
              if (data.series.isNotEmpty) ...[
                const _SectionHeader('Series'),
                for (final series in data.series)
                  _ResultTile(
                    title: series.name,
                    imageUrl: series.posterUrl,
                    subtitle: [
                      if (series.year != null) '${series.year}',
                      if (series.genre != null) series.genre!,
                    ].join(' · '),
                    onTap: () {
                      _record();
                      context.push('/series/${series.id}');
                    },
                  ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Empty-box state (PRD §8.6): recent searches, tap to re-run, swipe/× to
/// remove, or clear all. Falls back to a hint when there's no history.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({
    required this.onTapQuery,
    required this.onRemove,
    required this.onClear,
  });

  final void Function(String) onTapQuery;
  final Future<void> Function(String) onRemove;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return recent.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (queries) {
        if (queries.isEmpty) {
          return const Center(
            child: Text('Search movies, series, and channels.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent searches', style: AppTypography.title),
                  TextButton(onPressed: onClear, child: const Text('Clear all')),
                ],
              ),
            ),
            for (final q in queries)
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.textSecondary),
                title: Text(q),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: () => onRemove(q),
                ),
                onTap: () => onTapQuery(q),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: AppTypography.title),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
    this.contain = false,
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final VoidCallback onTap;

  /// Channel logos are contained on a square tile; posters cover a 2:3 tile.
  final bool contain;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: contain
          ? Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => const Icon(
                          Icons.live_tv, color: AppColors.textSecondary))
                  : const Icon(Icons.live_tv, color: AppColors.textSecondary),
            )
          : SizedBox(
              width: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: imageUrl != null
                      ? Image.network(imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const ColoredBox(
                                  color: AppColors.surfaceElevated))
                      : const ColoredBox(color: AppColors.surfaceElevated),
                ),
              ),
            ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!,
              style: const TextStyle(color: AppColors.textSecondary))
          : null,
    );
  }
}
