import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Cache-first movie lookup for the detail route; enrichment + the full
/// §8.7 page (cast, resume button, favorite) land in Task 1.2.
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

class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

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
        data: (m) {
          if (m == null) {
            return const Center(child: Text('Not found in the catalog.'));
          }
          final image = m.backdropUrl ?? m.posterUrl;
          final meta = [
            if (m.year != null) '${m.year}',
            if (m.genre != null) m.genre!,
            if (m.durationSeconds != null) '${m.durationSeconds! ~/ 60} min',
            if (m.rating != null) '★ ${m.rating!.toStringAsFixed(1)}',
          ].join('  ·  ');
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                    else
                      const ColoredBox(color: AppColors.surfaceElevated),
                    const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppColors.scrim)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: AppTypography.display.copyWith(fontSize: 28)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(meta,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                    if (m.plot != null) ...[
                      const SizedBox(height: 16),
                      Text(m.plot!, style: AppTypography.body),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'The full detail page (play/resume, favorite, cast) '
                      'arrives with Tasks 1.2 and 1.4.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
