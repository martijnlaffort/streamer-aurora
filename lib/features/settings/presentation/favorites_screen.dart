import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Favorites resolved against the cached catalog (PRD §8.11). Live-channel
/// favorites surface with Live TV in Phase 2.
final favoritesViewProvider = FutureProvider<
    ({List<Movie> movies, List<Series> series})>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return (movies: <Movie>[], series: <Series>[]);
  final catalog = ref.watch(catalogRepositoryProvider);
  final favorites = await ref.watch(favoritesRepositoryProvider).all();

  final movies = <Movie>[];
  final series = <Series>[];
  for (final (contentKey, _) in favorites) {
    final key = parseContentKey(contentKey);
    if (key == null || key.accountId != account.id) continue;
    if (key.type == StreamType.movie.name) {
      final movie = await catalog.movieById(account, key.id);
      if (movie != null) movies.add(movie);
    } else if (key.type == 'series') {
      final s = await catalog.seriesById(account, key.id);
      if (s != null) series.add(s);
    }
  }
  return (movies: movies, series: series);
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

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
          if (data.movies.isEmpty && data.series.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No favorites yet.'),
                  Text('Tap the heart on any detail page.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          final items = [
            for (final m in data.movies)
              (m.name, m.posterUrl, '/movie/${m.id}'),
            for (final s in data.series)
              (s.name, s.posterUrl, '/series/${s.id}'),
          ];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.54,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final (title, image, route) = items[i];
              return PosterCard(
                title: title,
                imageUrl: image,
                onTap: () => context.push(route),
              );
            },
          );
        },
      ),
    );
  }
}
