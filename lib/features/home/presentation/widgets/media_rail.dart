import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// A titled, horizontally scrolling rail (PRD §8.2/§10). Builder-based so
/// large catalogs only build visible cards.
class MediaRail extends StatelessWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 236,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(title, style: AppTypography.title),
        ),
        SizedBox(
          height: height,
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
