import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A newer build than the one running.
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.pageUrl,
    this.apkUrl,
    this.ipaUrl,
    this.notes,
  });

  final int build;

  /// The release page — the one link that works everywhere.
  final String pageUrl;
  final String? apkUrl;
  final String? ipaUrl;
  final String? notes;
}

/// Asks GitHub whether a newer build has been released.
///
/// This is a sideloaded app: no store tells anyone a new version exists. Builds
/// go out every few days and the only person who knows is the one who made
/// them, so friends run whatever they installed in August forever. Each build
/// is now published as a GitHub Release tagged `b<number>`; the app compares
/// that number to its own.
///
/// The repository is public, so this is one unauthenticated GET against a
/// generous rate limit, once per launch. Any failure — offline, rate-limited,
/// GitHub down — is "no update", never an error the user sees: an update
/// prompt is a courtesy, and a courtesy must not turn into a nag.
class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'Accept': 'application/vnd.github+json'},
            ));

  final Dio _dio;

  static const _latest =
      'https://api.github.com/repos/martijnlaffort/streamer-aurora/releases/latest';

  static final _tag = RegExp(r'^b(\d+)$');

  Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      // A build without a number (a local `flutter run`) has nothing to
      // compare against and must not be told it is out of date.
      if (current == 0) return null;

      final response = await _dio.get<Map<String, dynamic>>(_latest);
      final data = response.data;
      if (data == null) return null;
      final tag = _tag.firstMatch(data['tag_name'] as String? ?? '');
      if (tag == null) return null;
      final build = int.parse(tag.group(1)!);
      if (build <= current) return null;

      String? apk, ipa;
      for (final a in (data['assets'] as List?) ?? const []) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        final url = a['browser_download_url'] as String?;
        if (name.endsWith('.apk')) apk = url;
        if (name.endsWith('.ipa')) ipa = url;
      }
      return UpdateInfo(
        build: build,
        pageUrl: data['html_url'] as String,
        apkUrl: apk,
        ipaUrl: ipa,
        notes: data['body'] as String?,
      );
    } on Object {
      return null;
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((_) => UpdateService());

/// The newer build, if there is one. Resolved once per app session.
final availableUpdateProvider = FutureProvider<UpdateInfo?>(
    (ref) => ref.watch(updateServiceProvider).check());
