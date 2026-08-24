import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/cast/cast_service.dart';

/// Device chooser for casting.
///
/// Built here rather than using the Cast SDK's own dialog: that one is a
/// phone-shaped Material view that cannot be driven with a D-pad, so it would be
/// unusable on the television build and look foreign everywhere else.
///
/// Returns true when the user picked a device (the caller then loads the
/// stream), false or null when they backed out.
Future<bool?> showCastPicker(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => const SafeArea(child: _CastPicker()),
  );
}

class _CastPicker extends ConsumerWidget {
  const _CastPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(castDevicesProvider);
    final status = ref.watch(castStatusProvider).value ?? const CastStatus();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Text('Cast to', style: AppTypography.title),
              const Spacer(),
              if (status.isCasting)
                TextButton(
                  onPressed: () async {
                    await ref.read(castServiceProvider).disconnect();
                    if (context.mounted) Navigator.pop(context, false);
                  },
                  child: const Text('Stop casting'),
                ),
            ],
          ),
        ),
        devices.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Looking for devices…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e',
                style: const TextStyle(color: AppColors.error)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Text(
                  'No devices found. A Chromecast has to be on the same '
                  'network as this device.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, device) in list.indexed)
                  ListTile(
                    autofocus: i == 0,
                    leading: Icon(
                      device.connected ? Icons.cast_connected : Icons.cast,
                      color: device.connected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    title: Text(device.name),
                    subtitle: device.description == null
                        ? null
                        : Text(device.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      await ref.read(castServiceProvider).connect(device.id);
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ],
    );
  }
}
