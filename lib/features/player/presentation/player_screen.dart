import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../player_request.dart';

/// Route stub — the real media_kit player replaces this in Task 1.4.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.request});

  final PlayerRequest request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(),
      body: Center(
        child: Text(
          'Player for "${request.startItem.title}" arrives in Task 1.4.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
