import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Deliberately blank (Task 0.1): proves the theme, router, and scaffold are
/// alive. The real Home (hero, Continue Watching, rails) is Task 1.1.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
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
    );
  }
}
