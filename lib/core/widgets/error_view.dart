import 'package:flutter/material.dart';

import '../../data/sources/playlist_source.dart' show SourceException;
import '../theme/app_colors.dart';

/// A failure the user can read, with a way out.
///
/// Screens used to render `Text('$e')`, which put strings like
/// `SourceException: Could not reach the panel: SocketException...` on screen
/// as the entire error state — a stack-trace-grade string in place of copy,
/// with nothing to tap.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.title});

  final Object error;
  final VoidCallback? onRetry;

  /// Optional override for the headline; defaults to a message inferred from
  /// the error type.
  final String? title;

  /// Plain-language message. [SourceException] already carries copy written for
  /// humans, so it is used as-is; anything else gets a generic line, because an
  /// arbitrary Dart exception's `toString()` is not something to show anyone.
  static String messageFor(Object error) {
    if (error is SourceException) return error.message;
    return 'Something went wrong. Your saved catalogue is still available.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              title ?? 'Can’t load this right now',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              messageFor(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A friendly empty state: what is missing, and what to do about it.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
