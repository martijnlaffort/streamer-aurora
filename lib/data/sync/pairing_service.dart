import 'package:dio/dio.dart';

import '../../domain/models/models.dart';
import '../sources/playlist_source.dart' show SourceException;
import 'sync_config.dart';

/// Everything a new device needs to be fully set up: the playlists, and the
/// sync credentials that make it the same user everywhere.
///
/// The panel password travels deliberately — the point of pairing is that
/// nothing has to be typed on a remote. It is carried to the server, held for
/// seconds, and deleted the instant the TV collects it (see the backend's
/// PairingController).
class PairingPayload {
  const PairingPayload({required this.accounts, this.sync});

  final List<Account> accounts;
  final SyncConfig? sync;

  Map<String, dynamic> toJson() => {
        'version': 1,
        if (sync != null)
          'sync': {'base_url': sync!.baseUrl, 'token': sync!.token},
        'accounts': [
          for (final a in accounts)
            {
              'type': a.type.name,
              'name': a.name,
              'server_url': a.serverUrl,
              'username': a.username,
              'password': a.password,
              'epg_url': a.epgUrl,
            },
        ],
      };

  /// Rebuilds the payload on the receiving device.
  ///
  /// Account ids are NOT carried across — they are re-derived locally with
  /// [stableAccountId]. That keeps one source of truth for identity, and means
  /// a paired device and a hand-typed one land on exactly the same id.
  static PairingPayload fromJson(Map<String, dynamic> json, DateTime now) {
    final rawSync = json['sync'];
    final accounts = <Account>[];
    for (final entry in (json['accounts'] as List? ?? const [])) {
      final map = (entry as Map).cast<String, dynamic>();
      final type = AccountType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AccountType.xtream,
      );
      final serverUrl = (map['server_url'] as String?) ?? '';
      final username = (map['username'] as String?) ?? '';
      accounts.add(Account(
        id: stableAccountId(
            type: type, serverUrl: serverUrl, username: username),
        type: type,
        name: (map['name'] as String?) ?? 'My playlist',
        serverUrl: serverUrl,
        username: username,
        password: (map['password'] as String?) ?? '',
        createdAt: now,
        epgUrl: map['epg_url'] as String?,
      ));
    }
    return PairingPayload(
      accounts: accounts,
      sync: rawSync is Map
          ? SyncConfig(
              baseUrl: rawSync['base_url'] as String?,
              token: rawSync['token'] as String?,
              enabled: true,
            )
          : null,
    );
  }
}

/// An open pairing session, as held by the device displaying the code.
class PairingSession {
  const PairingSession({required this.code, required this.secret});

  /// Shown on screen for a person to read and type on their phone.
  final String code;

  /// Never displayed. Without it the payload cannot be collected, which is what
  /// stops a bystander who merely reads the code off the screen.
  final String secret;
}

/// Client for the pairing endpoints.
///
/// Unlike the rest of the sync layer this is mostly *unauthenticated*: a device
/// being set up has no token yet, since acquiring one is the point.
class PairingService {
  PairingService({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api',
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;

  /// Opens a session. Called by the device being set up.
  Future<PairingSession> open() async {
    try {
      final response =
          await _dio.post<Map<String, dynamic>>('/pairing');
      final data = response.data!;
      return PairingSession(
        code: data['code'] as String,
        secret: data['secret'] as String,
      );
    } on DioException catch (e) {
      throw SourceException(_message(e, 'Could not start pairing'), e);
    }
  }

  /// Polls for the payload. Returns null while the phone has not sent it yet.
  ///
  /// Throws when the session is gone — expired, or already collected — which
  /// the caller surfaces as "start again on the TV" rather than retrying
  /// forever.
  Future<PairingPayload?> collect(PairingSession session, DateTime now) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/pairing/${session.code}',
        queryParameters: {'secret': session.secret},
      );
      final data = response.data!;
      if (data['status'] != 'claimed') return null;
      return PairingPayload.fromJson(
          (data['payload'] as Map).cast<String, dynamic>(), now);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const SourceException(
            'This pairing code has expired. Start again on your TV.');
      }
      throw SourceException(_message(e, 'Could not check for a pairing'), e);
    }
  }

  /// Sends this device's configuration against a code. Called by the phone,
  /// which is the side that already has a token.
  Future<void> claim({
    required String code,
    required String token,
    required PairingPayload payload,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/pairing/${code.trim().toUpperCase()}/claim',
        data: {'payload': payload.toJson()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        throw const SourceException(
            'That code is not valid any more. Check the code on your TV, or '
            'start pairing again there.');
      }
      if (code == 409) {
        throw const SourceException('That code has already been used.');
      }
      if (code == 401 || code == 403) {
        throw const SourceException(
            'Your sync token was rejected. Check Settings → Sync.');
      }
      throw SourceException(_message(e, 'Could not send your settings'), e);
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return '$fallback: ${e.message ?? 'the server could not be reached'}';
  }
}
