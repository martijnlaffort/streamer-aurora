import 'package:equatable/equatable.dart';

import 'enums.dart';

/// A saved playlist account (PRD §7 `accounts`).
///
/// [password] is only ever persisted via flutter_secure_storage, referenced by
/// key — never written to SQLite (global rule). It lives on the in-memory model
/// so sources can build request/stream URLs.
class Account extends Equatable {
  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.createdAt,
    this.epgUrl,
    this.userAgent,
    this.altHosts = const [],
  });

  final String id;
  final AccountType type;

  /// User-facing label ("Home", "Backup provider"...).
  final String name;

  /// Xtream panel base URL, or the M3U playlist URL.
  final String serverUrl;
  final String username;
  final String password;

  /// UTC.
  final DateTime createdAt;

  /// Optional XMLTV EPG url (M3U accounts only).
  final String? epgUrl;

  /// What to send as `User-Agent` for this playlist's streams.
  ///
  /// Per account rather than global because it is a property of the PROVIDER:
  /// many panels serve `player_api.php` to anyone but only hand over the actual
  /// video to a whitelisted player UA, and which string is accepted differs
  /// between them. Null falls back to the app's default.
  final String? userAgent;

  /// Other hostnames the same provider answers on.
  ///
  /// Providers hand out several, and they are not interchangeable in practice:
  /// one can be blocked, rate-limited, or routed badly from a given exit IP
  /// while another works. Tried in order when a stream will not open.
  final List<String> altHosts;

  Account copyWith({
    String? name,
    String? serverUrl,
    String? username,
    String? password,
    String? epgUrl,
    String? userAgent,
    List<String>? altHosts,
    bool clearUserAgent = false,
  }) =>
      Account(
        id: id,
        type: type,
        name: name ?? this.name,
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        createdAt: createdAt,
        epgUrl: epgUrl ?? this.epgUrl,
        userAgent: clearUserAgent ? null : (userAgent ?? this.userAgent),
        altHosts: altHosts ?? this.altHosts,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        serverUrl,
        username,
        password,
        createdAt,
        epgUrl,
        userAgent,
        altHosts,
      ];

  @override
  bool get stringify => true;
}
