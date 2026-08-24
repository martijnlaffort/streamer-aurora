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
