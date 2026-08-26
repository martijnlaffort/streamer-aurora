import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// About & credits.
///
/// Exists primarily because TMDB's terms require attribution wherever their
/// data or images are used, and Dawn Player uses both: the discovery rails are built
/// from TMDB's ranked lists, and missing posters are filled from their image
/// CDN. The wording below is the acknowledgement TMDB asks for — that Dawn Player
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
          Text('Dawn Player', style: AppTypography.title),
          const SizedBox(height: 4),
          const _BuildIdentity(),
          const SizedBox(height: 10),
          const Text(
            'A player for your own IPTV subscription. Dawn Player does not provide, '
            'host or resell any channels or media — it plays what your own '
            'playlist gives it.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 28),
          Text('Credits', style: AppTypography.title.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          const _Credit(
            name: 'The Movie Database (TMDB)',
            body: 'Dawn Player uses the TMDB API to work out what is genuinely '
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
            name: 'Typefaces',
            body: 'Set in Outfit and Inter, both bundled with the app under '
                'the SIL Open Font License 1.1. The full licence text is in '
                'the licence page.',
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

/// Which build this actually is.
///
/// Exists because "is this the new version?" was, twice, impossible to answer
/// from inside the app — once when cleaned-up titles appeared to be missing,
/// and once when a Settings entry did. Both were stale installs, and both cost
/// more time to diagnose than this line takes to read.
///
/// The version and build number come from the platform bundle, so they cannot
/// drift from what was actually shipped. The commit is injected at build time
/// (`--dart-define=DAWN_COMMIT`) and is the part that matters — it maps a
/// device back to an exact source revision. It reads `local` for a build made
/// without the flag, which is itself useful information.
class _BuildIdentity extends StatelessWidget {
  const _BuildIdentity();

  static const _commit =
      String.fromEnvironment('DAWN_COMMIT', defaultValue: 'local');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? '…'
            : '${info.version} (${info.buildNumber})';
        return SelectableText(
          '$version · $_commit',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        );
      },
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
