import 'package:equatable/equatable.dart';

/// A live TV channel (PRD §7 `channels`).
class Channel extends Equatable {
  const Channel({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    required this.cachedAt,
    this.logoUrl,
    this.epgChannelId,
    this.sortOrder,
    this.hasArchive = false,
    this.archiveDays,
  });

  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? logoUrl;

  /// Key into the EPG (Xtream `epg_channel_id` / XMLTV channel id).
  final String? epgChannelId;
  final int? sortOrder;

  /// The panel keeps a rolling recording of this channel, so programmes that
  /// have already aired can still be played (catch-up / timeshift).
  final bool hasArchive;

  /// How far back the archive reaches, in days. Null when the panel advertises
  /// an archive without saying how long — treated as a short window.
  final int? archiveDays;

  /// The oldest moment still expected to be playable. Used to hide catch-up on
  /// programmes that have already fallen out of the window.
  DateTime? archiveHorizon(DateTime now) => hasArchive
      ? now.subtract(Duration(days: archiveDays ?? _defaultArchiveDays))
      : null;

  /// Panels commonly advertise `tv_archive: 1` with no duration. Assuming a
  /// couple of days is better than assuming none (which would hide the feature
  /// entirely) or assuming weeks (which would offer dead links).
  static const _defaultArchiveDays = 2;

  /// When this row was cached locally (UTC) — drives the cache TTL.
  final DateTime cachedAt;

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        name,
        logoUrl,
        epgChannelId,
        sortOrder,
        hasArchive,
        archiveDays,
        cachedAt,
      ];

  @override
  bool get stringify => true;
}
