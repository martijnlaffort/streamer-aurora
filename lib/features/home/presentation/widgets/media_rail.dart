import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers.dart';
import '../../../../core/theme/app_typography.dart';

/// A titled, horizontally scrolling rail (PRD §8.2/§10). Builder-based so
/// large catalogs only build visible cards.
class MediaRail extends ConsumerWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 236,
    this.onSeeAll,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;

  /// When set, the heading gets a trailing "See all" that opens the full,
  /// paged grid for this rail. Home's rails pass nothing.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rails are laid out in logical pixels, so the size preference has to be
    // applied here; text elsewhere scales through MediaQuery.
    final scale = ref.watch(uiScaleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, onSeeAll == null ? 16 : 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('See all',
                      style: TextStyle(color: AppColors.accentAlt)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

/// Stand-in for a rail whose category has not resolved yet.
///
/// Built FROM [MediaRail] rather than hand-sized, and that is the whole point:
/// it is guaranteed to occupy exactly the height of the real thing. When it was
/// laid out by hand the two differed by ~30px, so every rail that resolved
/// nudged everything below it — and a tab of dozens of rails resolving as you
/// scrolled jittered continuously.
class CategoryRailPlaceholder extends StatelessWidget {
  const CategoryRailPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MediaRail(
      title: title,
      itemCount: 4,
      itemBuilder: (context, i) => Container(
        width: 128,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
