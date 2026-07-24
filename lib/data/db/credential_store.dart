import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where account credentials live — and the ONLY place they live (global
/// rule: never plain SQLite). Abstract so unit tests can substitute an
/// in-memory fake (the real implementation needs platform keychains).
abstract interface class CredentialStore {
  Future<void> savePassword(String accountId, String password);

  /// Returns null when no credential is stored for [accountId].
  Future<String?> readPassword(String accountId);

  Future<void> deletePassword(String accountId);
}

/// Keychain/Keystore-backed implementation via flutter_secure_storage.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String accountId) => 'account_password_$accountId';

  @override
  Future<void> savePassword(String accountId, String password) =>
      _storage.write(key: _key(accountId), value: password);

  @override
  Future<String?> readPassword(String accountId) =>
      _storage.read(key: _key(accountId));

  @override
  Future<void> deletePassword(String accountId) =>
      _storage.delete(key: _key(accountId));
}
