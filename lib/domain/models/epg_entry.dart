import 'package:equatable/equatable.dart';

/// One programme in the guide (PRD §7 `epg_cache`).
class EpgEntry extends Equatable {
  const EpgEntry({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
  });

  final String channelId;

  /// UTC — converted to local time only at the display edge (global rule).
  final DateTime start;

  /// UTC.
  final DateTime stop;
  final String title;
  final String? description;

  @override
  List<Object?> get props => [channelId, start, stop, title, description];

  @override
  bool get stringify => true;
}
