import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Deliberately blank (Task 0.1): proves the theme, router, and scaffold are
/// alive. The real Home (hero, Continue Watching, rails) is Task 1.1.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aurora', style: AppTypography.display),
                SizedBox(height: 8),
                Text(
                  'Something beautiful is coming.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Dev-only entry to the source probe harness (Task 0.2).
          if (kDebugMode)
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.bug_report_outlined,
                      color: AppColors.textSecondary),
                  tooltip: 'Source probe',
                  onPressed: () => context.push('/dev/source-probe'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
