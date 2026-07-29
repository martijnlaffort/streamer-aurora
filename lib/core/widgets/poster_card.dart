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
    this.heroTag,
    this.rating,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double width;

  /// Shared-element tag: the detail header carries the same tag so the
  /// artwork flies poster → detail (PRD §10).
  final String? heroTag;

  /// When set (>0), a small star badge is drawn on the poster — used by the
  /// "Popular" rails to signal why a title is there.
  final double? rating;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _engaged = false;

  Widget _maybeHero(Widget child) =>
      widget.heroTag != null ? Hero(tag: widget.heroTag!, child: child) : child;

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
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _maybeHero(ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                border: _engaged
                                    ? Border.all(
                                        color: AppColors.focusRing, width: 2)
                                    : null,
                              ),
                              child: widget.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.imageUrl!,
                                      fit: BoxFit.cover,
                                      fadeInDuration:
                                          const Duration(milliseconds: 180),
                                      placeholder: (context, url) =>
                                          const ColoredBox(
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
                          )),
                        ),
                        if (widget.rating != null && widget.rating! > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _RatingBadge(widget.rating!),
                          ),
                      ],
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

/// A small "★ 8.4" chip drawn over a poster's top-right corner.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge(this.rating);

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.accentAlt),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
