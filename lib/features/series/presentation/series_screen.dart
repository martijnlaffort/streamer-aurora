import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — Series browsing lands in Task 1.3.
class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Series', style: TextStyle(fontSize: 20)),
            Text('Browsing arrives in Task 1.3.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
