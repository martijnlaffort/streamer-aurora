import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';

/// Deliberately minimal (real Home lands in Task 1.1): proves theme, router,
/// and — since Task 0.5 — which account is active.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Aurora', style: AppTypography.display),
                const SizedBox(height: 8),
                const Text(
                  'Something beautiful is coming.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                switch (active) {
                  AsyncData(value: final account?) => Chip(
                      avatar: const Icon(Icons.dns_outlined,
                          size: 16, color: AppColors.accent),
                      label: Text(account.name),
                    ),
                  AsyncData() => TextButton.icon(
                      onPressed: () => context.push('/accounts'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first account'),
                    ),
                  _ => const SizedBox(height: 32),
                },
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: Row(
                children: [
                  // Dev-only source probe (Task 0.2).
                  if (kDebugMode)
                    IconButton(
                      icon: const Icon(Icons.bug_report_outlined,
                          color: AppColors.textSecondary),
                      tooltip: 'Source probe',
                      onPressed: () => context.push('/dev/source-probe'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary),
                    tooltip: 'Accounts',
                    onPressed: () => context.push('/accounts'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
