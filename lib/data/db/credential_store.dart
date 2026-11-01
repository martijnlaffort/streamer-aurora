import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where account credentials live — and the ONLY place they live (global
/// rule: never plain SQLite). Abstract so unit tests can substitute an
/// in-memory fake (the real implementation needs platform keychains).
abstract interface class CredentialStore {
  Future<void> savePassword(String accountId, String password);

  /// Returns null when no credential is stored for [accountId].
  Future<String?> readPassword(String accountId);

  Future<void> deletePassword(String accountId);

  /// Remembers that [accountId] was deleted on this device, so sync does not
  /// adopt it again from the server or another device. Kept here rather than
  /// in drift because it must outlive the account's row.
  Future<void> markDeleted(String accountId);

  Future<bool> isDeleted(String accountId);

  /// Forgets the deletion — the playlist was added again on purpose.
  Future<void> clearDeleted(String accountId);
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

  String _deletedKey(String accountId) => 'account_deleted_$accountId';

  @override
  Future<void> markDeleted(String accountId) =>
      _storage.write(key: _deletedKey(accountId), value: 'true');

  @override
  Future<bool> isDeleted(String accountId) async =>
      await _storage.read(key: _deletedKey(accountId)) == 'true';

  @override
  Future<void> clearDeleted(String accountId) =>
      _storage.delete(key: _deletedKey(accountId));
}
