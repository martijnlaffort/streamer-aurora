import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Unified instant search over the cached catalog (PRD §8.6): debounced,
/// no network round-trips. Channels join in Phase 2 with Live TV.
final searchResultsProvider = FutureProvider.family<
    ({List<Movie> movies, List<Series> series}), String>((ref, query) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null || query.trim().length < 2) {
    return (movies: <Movie>[], series: <Series>[]);
  }
  final catalog = ref.watch(catalogRepositoryProvider);
  final q = query.trim();
  return (
    movies: await catalog.searchMovies(account, q),
    series: await catalog.searchSeries(account, q),
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

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          autofocus: false,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Search movies and series…',
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
            return const Center(
              child: Text('Type at least two characters.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          if (data.movies.isEmpty && data.series.isEmpty) {
            return Center(
              child: Text('Nothing found for “${_query.trim()}”.',
                  style: const TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView(
            children: [
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
                    onTap: () => context.push('/movie/${movie.id}'),
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
                    onTap: () => context.push('/series/${series.id}'),
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
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: imageUrl != null
                ? Image.network(imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: AppColors.surfaceElevated))
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
