import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — unified search lands in Task 1.7.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Search', style: TextStyle(fontSize: 20)),
            Text('Instant search arrives in Task 1.7.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
