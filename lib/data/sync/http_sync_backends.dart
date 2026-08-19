import 'package:dio/dio.dart';

import '../../domain/models/models.dart';
import '../repositories/sync_backend.dart';

/// Dio-backed implementations of the sync seam (PRD §9) against the Laravel
/// API in `backend/`. One shared bearer token authenticates every call.
class _ApiClient {
  _ApiClient({required String baseUrl, required String token, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api',
              headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;
}

class HttpProgressSyncBackend implements ProgressSyncBackend {
  HttpProgressSyncBackend(
      {required String baseUrl, required String token, Dio? dio})
      : _api = _ApiClient(baseUrl: baseUrl, token: token, dio: dio);

  final _ApiClient _api;

  @override
  Future<void> push(List<WatchProgress> entries) async {
    if (entries.isEmpty) return;
    await _api._dio.post('/progress', data: {
      'entries': [
        for (final e in entries)
          {
            'content_key': e.contentKey,
            if (e.seriesId != null) 'series_id': e.seriesId,
            'position_seconds': e.positionSeconds,
            'duration_seconds': e.durationSeconds,
            'completed': e.completed,
            'updated_at': e.updatedAt.toUtc().toIso8601String(),
          },
      ],
    });
  }

  @override
  Future<List<WatchProgress>> pullSince(DateTime? since) async {
    final response = await _api._dio.get<Map<String, dynamic>>(
      '/progress',
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    final entries = (response.data?['entries'] as List?) ?? const [];
    return [
      for (final e in entries.cast<Map<String, dynamic>>())
        WatchProgress(
          contentKey: e['content_key'] as String,
          seriesId: e['series_id'] as String?,
          positionSeconds: (e['position_seconds'] as num).toInt(),
          durationSeconds: (e['duration_seconds'] as num).toInt(),
          updatedAt: DateTime.parse(e['updated_at'] as String).toUtc(),
          completed: e['completed'] as bool? ?? false,
        ),
    ];
  }
}

class HttpPreferencesSyncBackend implements PreferencesSyncBackend {
  HttpPreferencesSyncBackend(
      {required String baseUrl, required String token, Dio? dio})
      : _api = _ApiClient(baseUrl: baseUrl, token: token, dio: dio);

  final _ApiClient _api;

  @override
  Future<void> push(Preferences preferences, DateTime updatedAt) async {
    await _api._dio.put('/preferences', data: {
      'preferred_audio_lang': preferences.preferredAudioLang,
      'preferred_subtitle_lang': preferences.preferredSubtitleLang,
      'autoplay_next': preferences.autoplayNext,
      'background_playback': preferences.backgroundPlayback,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<({Preferences prefs, DateTime updatedAt})?> pull() async {
    final response =
        await _api._dio.get<Map<String, dynamic>>('/preferences');
    final p = response.data?['preferences'] as Map<String, dynamic>?;
    if (p == null) return null;
    return (
      prefs: Preferences(
        preferredAudioLang: p['preferred_audio_lang'] as String?,
        preferredSubtitleLang: p['preferred_subtitle_lang'] as String?,
        autoplayNext: p['autoplay_next'] as bool? ?? true,
        backgroundPlayback: p['background_playback'] as bool? ?? false,
      ),
      updatedAt: DateTime.parse(p['updated_at'] as String).toUtc(),
    );
  }
}

class HttpFavoritesSyncBackend implements FavoritesSyncBackend {
  HttpFavoritesSyncBackend(
      {required String baseUrl, required String token, Dio? dio})
      : _api = _ApiClient(baseUrl: baseUrl, token: token, dio: dio);

  final _ApiClient _api;

  @override
  Future<void> push(List<FavoriteRecord> records) async {
    if (records.isEmpty) return;
    await _api._dio.post('/favorites', data: {
      'entries': [
        for (final r in records)
          {
            'content_key': r.contentKey,
            'removed': r.removed,
            'added_at': r.addedAt.toUtc().toIso8601String(),
            'updated_at': r.updatedAt.toUtc().toIso8601String(),
          },
      ],
    });
  }

  @override
  Future<List<FavoriteRecord>> pull() async {
    final response = await _api._dio.get<Map<String, dynamic>>('/favorites');
    final favorites = (response.data?['favorites'] as List?) ?? const [];
    return [
      for (final f in favorites.cast<Map<String, dynamic>>())
        (
          contentKey: f['content_key'] as String,
          removed: f['removed'] as bool? ?? false,
          addedAt: DateTime.parse(f['added_at'] as String).toUtc(),
          updatedAt: DateTime.parse(
                  (f['updated_at'] ?? f['added_at']) as String)
              .toUtc(),
        ),
    ];
  }
}

class HttpAccountSyncBackend implements AccountSyncBackend {
  HttpAccountSyncBackend(
      {required String baseUrl, required String token, Dio? dio})
      : _api = _ApiClient(baseUrl: baseUrl, token: token, dio: dio);

  final _ApiClient _api;

  @override
  Future<void> push(List<AccountRecord> records) async {
    if (records.isEmpty) return;
    await _api._dio.post('/accounts', data: {
      'entries': [
        for (final r in records)
          {
            'account_id': r.accountId,
            'type': r.type,
            'name': r.name,
            'server_url': r.serverUrl,
            'username': r.username,
            'password': r.password,
            if (r.epgUrl != null) 'epg_url': r.epgUrl,
            'updated_at': r.updatedAt.toUtc().toIso8601String(),
          },
      ],
    });
  }

  @override
  Future<List<AccountRecord>> pull() async {
    final response = await _api._dio.get<Map<String, dynamic>>('/accounts');
    final accounts = (response.data?['accounts'] as List?) ?? const [];
    return [
      for (final a in accounts.cast<Map<String, dynamic>>())
        (
          accountId: a['account_id'] as String,
          type: a['type'] as String,
          name: a['name'] as String,
          serverUrl: a['server_url'] as String,
          username: a['username'] as String? ?? '',
          password: a['password'] as String? ?? '',
          epgUrl: a['epg_url'] as String?,
          updatedAt: DateTime.parse(a['updated_at'] as String).toUtc(),
        ),
    ];
  }
}
