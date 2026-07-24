import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 2:3 poster tile used by rails and (from Task 1.2) grids. Focus-aware from
/// the start (PRD §10): hover/D-pad focus scales the card slightly, so the
/// Android TV layer can reuse it unchanged.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.onTap,
    this.width = 128,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double width;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _engaged = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _engaged = true),
        onExit: (_) => setState(() => _engaged = false),
        child: Focus(
          onFocusChange: (focused) => setState(() => _engaged = focused),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _engaged ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          border: _engaged
                              ? Border.all(color: AppColors.focusRing, width: 2)
                              : null,
                        ),
                        child: widget.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                fadeInDuration:
                                    const Duration(milliseconds: 180),
                                placeholder: (context, url) => const ColoredBox(
                                    color: AppColors.surfaceElevated),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: AppColors.textSecondary),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.movie_outlined,
                                    color: AppColors.textSecondary),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
