import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — the full series page (seasons, episodes, progress) is
/// Task 1.3.
class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('Series $seriesId — detail arrives in Task 1.3.',
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
