import 'package:dio/dio.dart';

import '../../domain/models/discovery.dart';
import 'json_values.dart';
import 'playlist_source.dart' show SourceException;

/// "What is the world looking up today", from Wikimedia's pageviews API.
///
/// This exists to replace TMDB's trending rail with something that cannot be
/// rate-limited, priced, or revoked: the endpoint needs no key, no account and
/// no commercial tier, and the data is openly licensed.
///
/// It is also a better fit than a global streaming chart. A trending list from
/// a metadata provider is mostly titles a playlist does not carry; the
/// intersection of "what people are reading about today" with "what you
/// actually have" is both current AND watchable, and the catalogue match that
/// every discovery list already goes through does that filtering for free.
///
/// Queried per language project, so a Dutch device can be told what the
/// Netherlands is reading rather than what the United States is.
class WikipediaTrendingSource {
  WikipediaTrendingSource({
    this.projects = const ['en.wikipedia'],
    Dio? dio,
    DateTime Function()? clock,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              // Wikimedia asks that clients identify themselves, and blocks
              // generic agents.
              headers: {
                'User-Agent': 'Aurora/1.0 '
                    '(https://github.com/martijnlaffort/streamer-aurora)',
                'Accept': 'application/json',
              },
            )),
        _clock = clock ?? (() => DateTime.now().toUtc());

  /// Wikipedia language editions to read, best first. Results are merged, so a
  /// title trending in both is ranked by its better placement.
  final List<String> projects;
  final Dio _dio;
  final DateTime Function() _clock;

  static const _base = 'https://wikimedia.org/api/rest_v1/metrics/pageviews/top';

  /// Namespaced and meta pages that dominate the raw chart and are never
  /// titles. "Main Page" alone is usually rank 1 by an order of magnitude.
  static final _junk = RegExp(
    r'^(Main_Page|Special:|Wikipedia:|Portal:|Help:|Category:|File:|Talk:|'
    r'List_of|Deaths_in|-$)',
    caseSensitive: false,
  );

  /// `(film)`, `(2019 film)`, `(TV series)`, `(American TV series)`,
  /// `(miniseries)` — Wikipedia's own disambiguators, which double as a free
  /// type classifier.
  static final _filmSuffix = RegExp(r'\(([^)]*\b)?film\)$', caseSensitive: false);
  static final _seriesSuffix =
      RegExp(r'\(([^)]*\b)?(TV series|miniseries|TV programme)\)$',
          caseSensitive: false);

  /// How many complete days to pool.
  ///
  /// One day yields very few series — the disambiguator is simply rarer in the
  /// daily chart — and makes the rail hostage to one day's news. Three days is
  /// enough to fill it while still meaning "now".
  static const _days = 3;

  /// Complete days, most recent first. Today is still accumulating and 404s for
  /// much of the day, so it is skipped.
  List<DateTime> _recentDays() => [
        for (var i = 1; i <= _days; i++)
          _clock().subtract(Duration(days: i)),
      ];

  Future<List<dynamic>> _articles(String project, DateTime day) async {
    String two(int n) => n.toString().padLeft(2, '0');
    final url = '$_base/$project/all-access/'
        '${day.year}/${two(day.month)}/${two(day.day)}';
    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      final items = listOr(response.data?['items']);
      if (items.isEmpty) return const [];
      return listOr(optMap(items.first)?['articles']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const []; // No data for that day.
      throw SourceException(
          'Could not reach Wikipedia trending: ${e.message}', e);
    }
  }

  /// Titles trending today, filtered to the requested kind.
  ///
  /// An explicit `(film)` / `(TV series)` disambiguator is REQUIRED. The first
  /// version also admitted bare article names on the theory that the catalogue
  /// match would sort them out; run against a real day that accepted 947 of
  /// 1000 articles — people, place names, body parts — and against a 150k-title
  /// catalogue enough of those match something by coincidence to fill the rail
  /// with accidents. Wikipedia's own disambiguator is a free, reliable type
  /// signal and costs only the handful of films whose bare name is unambiguous.
  Future<List<DiscoveryTitle>> trending({required bool series}) async {
    // Best (lowest) rank wins when a title trends on more than one day or in
    // more than one language.
    final best = <String, ({String title, int rank})>{};

    for (final project in projects) {
      for (final day in _recentDays()) {
        final articles = await _articles(project, day);
        for (final row in articles) {
          final map = optMap(row);
          final raw = optString(map?['article']);
          final rank = optInt(map?['rank']);
          if (raw == null || rank == null || _junk.hasMatch(raw)) continue;

          final wanted =
              series ? _seriesSuffix.hasMatch(raw) : _filmSuffix.hasMatch(raw);
          if (!wanted) continue;

          final title = _clean(raw);
          if (title.length < 2) continue;
          final key = title.toLowerCase();
          final existing = best[key];
          if (existing == null || rank < existing.rank) {
            best[key] = (title: title, rank: rank);
          }
        }
      }
    }

    final ordered = best.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return [
      for (final (index, e) in ordered.indexed)
        DiscoveryTitle(title: e.title, rank: index),
    ];
  }

  /// Article name to a matchable title: underscores back to spaces, and the
  /// disambiguator removed since the catalogue does not carry it.
  String _clean(String article) => article
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
      .trim();
}
