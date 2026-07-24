import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';

/// Settings tab. The full settings surface (languages, autoplay, cache)
/// lands in Task 1.7 — for now: account management + dev tools.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Accounts'),
            subtitle: Text(
              switch (active) {
                AsyncData(value: final a?) => 'Active: ${a.name}',
                _ => 'No active account',
              },
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Source probe (dev)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/dev/source-probe'),
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.tune, color: AppColors.textSecondary),
            title: Text('Playback preferences'),
            subtitle: Text('Audio & subtitle language, autoplay — Task 1.6/1.7',
                style: TextStyle(color: AppColors.textSecondary)),
            enabled: false,
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Aurora',
            applicationVersion: '0.1.0',
            child: Text('About'),
          ),
        ],
      ),
    );
  }
}
