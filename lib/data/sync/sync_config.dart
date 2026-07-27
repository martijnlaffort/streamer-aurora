import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-facing sync settings (PRD §8.12/§9). The token is a credential, so the
/// whole config lives in secure storage — and it needs no DB schema change.
class SyncConfig {
  const SyncConfig({this.baseUrl, this.token, this.enabled = false});

  final String? baseUrl;
  final String? token;
  final bool enabled;

  bool get isConfigured =>
      enabled &&
      (baseUrl?.trim().isNotEmpty ?? false) &&
      (token?.trim().isNotEmpty ?? false);

  SyncConfig copyWith({String? baseUrl, String? token, bool? enabled}) =>
      SyncConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
        enabled: enabled ?? this.enabled,
      );
}

/// The sync watermarks the reconciler reads/writes. Split out so [SyncService]
/// depends on this rather than the secure-storage-backed store (tests inject
/// an in-memory one).
abstract interface class SyncStateStore {
  Future<DateTime?> lastSyncAt();
  Future<void> setLastSyncAt(DateTime at);
  Future<DateTime?> preferencesChangedAt();
  Future<void> setPreferencesChangedAt(DateTime at);
}

class SyncConfigStore implements SyncStateStore {
  SyncConfigStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kBase = 'sync_base_url';
  static const _kToken = 'sync_token';
  static const _kEnabled = 'sync_enabled';
  static const _kLastSync = 'sync_last_at';
  static const _kPrefsChanged = 'sync_prefs_changed_at';

  Future<SyncConfig> read() async {
    return SyncConfig(
      baseUrl: await _storage.read(key: _kBase),
      token: await _storage.read(key: _kToken),
      enabled: (await _storage.read(key: _kEnabled)) == 'true',
    );
  }

  Future<void> save(SyncConfig config) async {
    await _storage.write(key: _kBase, value: config.baseUrl);
    await _storage.write(key: _kToken, value: config.token);
    await _storage.write(key: _kEnabled, value: config.enabled.toString());
  }

  /// Progress `pullSince` watermark (UTC).
  @override
  Future<DateTime?> lastSyncAt() async =>
      _readMillis(await _storage.read(key: _kLastSync));

  @override
  Future<void> setLastSyncAt(DateTime at) =>
      _storage.write(key: _kLastSync, value: _millis(at));

  /// When preferences last changed locally — the LWW key sent on push.
  @override
  Future<DateTime?> preferencesChangedAt() async =>
      _readMillis(await _storage.read(key: _kPrefsChanged));

  @override
  Future<void> setPreferencesChangedAt(DateTime at) =>
      _storage.write(key: _kPrefsChanged, value: _millis(at));

  String _millis(DateTime dt) => dt.toUtc().millisecondsSinceEpoch.toString();

  DateTime? _readMillis(String? raw) {
    final v = raw == null ? null : int.tryParse(raw);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }
}
