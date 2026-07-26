import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/category_chips.dart';
import '../../../core/widgets/poster_card.dart';
import '../movies_providers.dart';

/// Movies browse (PRD §8.3): grid, category filter, sort.
class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  String? _categoryId;
  MovieSort _sort = MovieSort.added;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(vodCategoriesProvider);
    final movies = ref.watch(moviesListProvider(_categoryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          PopupMenuButton<MovieSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in MovieSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          categories.when(
            data: (list) => CategoryChips(
              categories: list,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            loading: () => const SizedBox(height: 44),
            error: (e, _) => const SizedBox(height: 44),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: movies.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e',
                      style: const TextStyle(color: AppColors.error))),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Nothing here yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final sorted = sortMovies(list, _sort);
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final movie = sorted[i];
                    return PosterCard(
                      title: movie.name,
                      imageUrl: movie.posterUrl,
                      onTap: () => context.push('/movie/${movie.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
