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

  @override
  List<Object?> get props =>
      [id, type, name, serverUrl, username, password, createdAt];

  @override
  bool get stringify => true;
}
