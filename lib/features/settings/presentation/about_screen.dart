import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// About & credits.
///
/// Exists primarily because TMDB's terms require attribution wherever their
/// data or images are used, and Aurora uses both: the discovery rails are built
/// from TMDB's ranked lists, and missing posters are filled from their image
/// CDN. The wording below is the acknowledgement TMDB asks for — that Aurora
/// uses the API but is not endorsed or certified by them.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Aurora', style: AppTypography.title),
          const SizedBox(height: 6),
          const Text(
            'A player for your own IPTV subscription. Aurora does not provide, '
            'host or resell any channels or media — it plays what your own '
            'playlist gives it.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 28),
          Text('Credits', style: AppTypography.title.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          const _Credit(
            name: 'The Movie Database (TMDB)',
            body: 'Aurora uses the TMDB API to work out what is genuinely '
                'popular and to find artwork for titles your provider supplies '
                'no image for.\n\n'
                'This product uses the TMDB API but is not endorsed or '
                'certified by TMDB.',
          ),
          const _Credit(
            name: 'libmpv / media_kit',
            body: 'Playback is handled by libmpv, the same engine behind mpv.',
          ),
          const _Credit(
            name: 'Award data',
            body: 'The award rails are built from a bundled list of Academy '
                'Award Best Picture and Primetime Emmy winners.',
          ),
        ],
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
