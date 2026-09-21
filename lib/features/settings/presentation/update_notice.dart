import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/updates/update_service.dart';

/// Opens the newer build the way this device can actually use it.
///
/// Android gets the APK itself: the browser downloads it and the system's
/// installer takes over. iOS gets the release page, because an .ipa on the
/// phone installs nothing — it goes through a computer (Sideloadly), so the
/// page with its notes is what the person needs. A television has no browser
/// to hand a link to, so it shows the address to open elsewhere; so does any
/// device where launching fails.
Future<void> openUpdate(
    BuildContext context, WidgetRef ref, UpdateInfo update) async {
  final url = defaultTargetPlatform == TargetPlatform.android
      ? update.apkUrl ?? update.pageUrl
      : update.pageUrl;
  if (!isTelevisionOf(ref)) {
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } on Object {
      // Fall through to showing the address.
    }
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Build ${update.build} is available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open this on a phone or computer:',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          SelectableText(update.pageUrl,
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// The "a newer build exists" card on the About screen. Renders nothing when
/// the running build is current, or when the check could not be made.
class UpdateNotice extends ConsumerWidget {
  const UpdateNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(availableUpdateProvider).value;
    if (update == null) return const SizedBox.shrink();
    final notes = update.notes?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => openUpdate(context, ref, update),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.system_update_alt, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Build ${update.build} is available',
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notes,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
