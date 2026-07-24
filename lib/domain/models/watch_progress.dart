import 'package:equatable/equatable.dart';

/// Playback position for one piece of content (PRD §7 `watch_progress`,
/// resume rules in §8.9).
class WatchProgress extends Equatable {
  const WatchProgress({
    required this.contentKey,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.syncedAt,
    this.completed = false,
  });

  /// Stable identity across accounts/types: `account:type:id` (PRD §7).
  final String contentKey;
  final int positionSeconds;
  final int durationSeconds;

  /// UTC — also the last-write-wins key for the future sync backend (PRD §9).
  final DateTime updatedAt;

  /// UTC; null until a backend exists and has seen this row.
  final DateTime? syncedAt;
  final bool completed;

  WatchProgress copyWith({
    int? positionSeconds,
    int? durationSeconds,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? completed,
  }) {
    return WatchProgress(
      contentKey: contentKey,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [
        contentKey,
        positionSeconds,
        durationSeconds,
        updatedAt,
        syncedAt,
        completed,
      ];

  @override
  bool get stringify => true;
}
