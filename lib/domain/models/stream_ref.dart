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
  });

  final String accountId;
  final StreamType type;
  final String streamId;
  final String? containerExt;

  @override
  List<Object?> get props => [accountId, type, streamId, containerExt];

  @override
  bool get stringify => true;
}
