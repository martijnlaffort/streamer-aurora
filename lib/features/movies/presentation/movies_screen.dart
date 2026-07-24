import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — the Movies grid with filters lands in Task 1.2.
class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Movies', style: TextStyle(fontSize: 20)),
            Text('Browsing arrives in Task 1.2.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
