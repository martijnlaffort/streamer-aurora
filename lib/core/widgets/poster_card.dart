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
    this.rank,
    this.autofocus = false,
  });

  /// Takes focus when first built — a TV needs *something* focused or the remote
  /// has nowhere to start. Set on the first card of the first rail only.
  final bool autofocus;

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double width;

  /// 1-based position in a Top 10 rail. Drawn as a large numeral over the
  /// poster's lower-left — the rank is the point of such a rail, so it has to
  /// read at a glance rather than sit in the caption.
  final int? rank;

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
    // Cap the decoded bitmap to the on-screen size. Without this every poster
    // decodes at full source resolution (a 1000×1500 poster ≈ 6 MB of RAM),
    // and a few rails' worth is enough to trip iOS's per-app memory limit and
    // kill the app while scrolling.
    final decodeWidth =
        (widget.width * MediaQuery.devicePixelRatioOf(context)).round();
    // The card is a picture plus a caption; without this a screen reader reads
    // the caption with no indication it is a button, and the rating/rank
    // badges are announced as loose numbers.
    return Semantics(
      button: true,
      label: [
        widget.title,
        if (widget.rank != null) 'number ${widget.rank}',
        if (widget.rating != null && widget.rating! > 0)
          'rated ${widget.rating!.toStringAsFixed(1)}',
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _engaged = true),
        onExit: (_) => setState(() => _engaged = false),
        // InkWell, NOT GestureDetector: a D-pad OK press arrives as an
        // ActivateIntent, which only widgets that register an Actions handler
        // respond to. With GestureDetector the card highlighted on focus but
        // pressing OK did nothing — focus without activation. InkWell handles
        // tap, Enter, Space and D-pad centre alike.
        child: InkWell(
          onTap: widget.onTap,
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(10),
          // The scale animation below is the focus affordance; Material's own
          // overlays would fight it.
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onFocusChange: (focused) {
            setState(() => _engaged = focused);
            // Bring the focused card into view — without this, moving along a
            // rail with the remote walks focus off the edge of the screen.
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
          },
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
                                      memCacheWidth: decodeWidth,
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
                        if (widget.rank != null)
                          Positioned(
                            left: 4,
                            bottom: 0,
                            child: _RankNumeral(widget.rank!),
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

/// A large rank numeral for Top 10 rails: filled glyph with a dark stroke so it
/// stays legible over both bright and dark artwork.
class _RankNumeral extends StatelessWidget {
  const _RankNumeral(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    final text = '$rank';
    // Stroke drawn as a second Text underneath — cheaper and sharper than a
    // shadow, and readable on white posters where a shadow washes out.
    return Stack(
      children: [
        Text(text,
            style: TextStyle(
              fontSize: 56,
              height: 1.0,
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = Colors.black.withValues(alpha: 0.85),
            )),
        Text(text,
            style: const TextStyle(
              fontSize: 56,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
      ],
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
