import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Everything needed to resolve a playable URL: account + type + id + container
/// extension (PRD §5). The URL itself is built by the account's source
/// (PRD §6.1) — the UI never assembles URLs.
class StreamRef extends Equatable {
  const StreamRef({
    required this.accountId,
    required this.type,
    required this.streamId,
    this.containerExt,
    this.catchupStart,
    this.catchupMinutes,
  });

  final String accountId;
  final StreamType type;
  final String streamId;
  final String? containerExt;

  /// Catch-up: play this live channel from a moment in the past rather than
  /// from the live edge. Set together with [catchupMinutes]. Live only — the
  /// panel serves it from its rolling recording of the channel.
  final DateTime? catchupStart;

  /// How much of the recording to request, in minutes (normally the
  /// programme's length).
  final int? catchupMinutes;

  /// A catch-up stream is a recording: it has a real duration and a real
  /// end, so the player treats it as VOD (seek bar, resume) rather than live.
  bool get isCatchup => catchupStart != null && catchupMinutes != null;

  @override
  List<Object?> get props =>
      [accountId, type, streamId, containerExt, catchupStart, catchupMinutes];

  @override
  bool get stringify => true;
}
