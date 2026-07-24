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
  });

  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? logoUrl;

  /// Key into the EPG (Xtream `epg_channel_id` / XMLTV channel id).
  final String? epgChannelId;
  final int? sortOrder;

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
        cachedAt,
      ];

  @override
  bool get stringify => true;
}
