import 'package:dawnplayer/data/db/app_database.dart';
import 'package:dawnplayer/data/db/credential_store.dart';
import 'package:drift/native.dart';

/// In-memory drift database for tests. sqlite3 3.x provides its native
/// library through Dart native assets, so this works in plain `flutter test`.
AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

/// Credential store fake — the real one needs platform keychains.
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> passwords = {};

  @override
  Future<void> savePassword(String accountId, String password) async {
    passwords[accountId] = password;
  }

  @override
  Future<String?> readPassword(String accountId) async => passwords[accountId];

  @override
  Future<void> deletePassword(String accountId) async {
    passwords.remove(accountId);
  }
}
