import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/app_colors.dart';

/// A vertical scroll of one rail per category — the Movies/Series tab body.
///
/// Uses a **builder**, not a fixed list of children: a real line can have
/// hundreds of categories, and only the rails near the viewport may be built.
/// That laziness is also what makes the per-rail fetch debounce work, since a
/// rail that is never built never asks for anything.
class CategoryRailsView extends StatelessWidget {
  const CategoryRailsView({
    super.key,
    required this.categories,
    required this.railBuilder,
    this.header,
  });

  final List<Category> categories;

  /// Builds the rail for one category. Return a zero-height widget to hide it.
  final Widget Function(BuildContext context, Category category) railBuilder;

  /// Optional widget above the first rail.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No categories in this playlist yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverList.builder(
          itemCount: categories.length,
          itemBuilder: (context, i) => railBuilder(context, categories[i]),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Placeholder shown while a rail's category is still loading, sized to match a
/// real rail so the list does not jump as content arrives.
class CategoryRailPlaceholder extends StatelessWidget {
  const CategoryRailPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 128,
                  height: 190,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
