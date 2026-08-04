import 'package:dio/dio.dart';

import '../../domain/models/discovery.dart';
import 'json_values.dart';
import 'playlist_source.dart' show SourceException;

/// TMDB client for the discovery rails (PRD §8.2).
///
/// The point of going to TMDB is the one thing an IPTV panel cannot give us: a
/// **vote count**. A panel exposes only `rating`, so sorting by it puts a film
/// rated 9.9 by four people above The Dark Knight — which is exactly why the
/// old "Popular" rail surfaced titles nobody recognises.
///
/// Rather than score the user's 150k titles (which would mean a TMDB lookup per
/// title), we pull a handful of small *already ranked* lists and later keep the
/// entries the playlist actually carries. That is ~8 requests per refresh cycle
/// instead of 150k, and it means **the playlist itself never leaves the
/// device** — we only ask TMDB for its own public lists.
class TmdbSource {
  TmdbSource({
    required this.apiKey,
    this.region = 'NL',
    this.language = 'en-US',
    Dio? dio,
    this.baseUrl = 'https://api.themoviedb.org/3',
    DateTime Function()? clock,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            )),
        _clock = clock ?? (() => DateTime.now().toUtc());

  final String apiKey;

  /// ISO 3166-1 country code — makes "popular" and "new releases" reflect what
  /// actually came out where the user is, rather than a US-centric view.
  final String region;
  final String language;
  final String baseUrl;
  final Dio _dio;
  final DateTime Function() _clock;

  /// A title needs this many votes before it can appear in a "new releases"
  /// rail. Fresh TMDB entries start at a handful of votes and wild averages;
  /// without a floor the rail fills with films nobody has seen either.
  static const _minVotesForNew = 25;

  Future<List<dynamic>> _results(
      String path, Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {
      'api_key': apiKey,
      'language': language,
      ...query,
    });
    final Response<dynamic> response;
    try {
      response = await _dio.getUri<dynamic>(uri);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        throw const SourceException('TMDB rejected the API key');
      }
      if (code == 429) {
        throw const SourceException('TMDB rate limit reached — try again later');
      }
      throw SourceException('Could not reach TMDB: ${e.message}', e);
    }
    final data = optMap(response.data);
    if (data == null) throw const SourceException('Unexpected TMDB response');
    return listOr(data['results']);
  }

  /// Maps a TMDB result row. Movies use `title`/`release_date`, TV uses
  /// `name`/`first_air_date`; everything else is shared.
  List<DiscoveryTitle> _map(List<dynamic> rows, {required bool isTv}) {
    final out = <DiscoveryTitle>[];
    for (final (index, row) in rows.indexed) {
      final map = optMap(row);
      if (map == null) continue;
      final title = optString(map[isTv ? 'name' : 'title']) ??
          optString(map[isTv ? 'original_name' : 'original_title']);
      if (title == null || title.trim().isEmpty) continue;
      final date = optString(map[isTv ? 'first_air_date' : 'release_date']);
      out.add(DiscoveryTitle(
        title: title,
        rank: index,
        tmdbId: optInt(map['id']),
        year: date != null && date.length >= 4
            ? int.tryParse(date.substring(0, 4))
            : null,
        voteAverage: optDouble(map['vote_average']),
        voteCount: optInt(map['vote_count']),
      ));
    }
    return out;
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // --- Movies ----------------------------------------------------------------

  /// What the world is actually watching this week.
  Future<List<DiscoveryTitle>> trendingMovies() async =>
      _map(await _results('/trending/movie/week', const {}), isTv: false);

  /// Popular right now, scoped to [region] so the ordering reflects local
  /// release and demand rather than the global default.
  Future<List<DiscoveryTitle>> popularMovies() async => _map(
      await _results('/discover/movie', {
        'sort_by': 'popularity.desc',
        'region': region,
        'vote_count.gte': '50',
      }),
      isTv: false);

  /// Released in [region] in the last 120 days, newest first.
  Future<List<DiscoveryTitle>> newReleaseMovies() async {
    final now = _clock();
    return _map(
        await _results('/discover/movie', {
          'sort_by': 'primary_release_date.desc',
          'region': region,
          'primary_release_date.gte':
              _isoDate(now.subtract(const Duration(days: 120))),
          'primary_release_date.lte': _isoDate(now),
          'vote_count.gte': '$_minVotesForNew',
        }),
        isTv: false);
  }

  /// TMDB's top-rated list, which applies a vote-weighted (Bayesian) average —
  /// the same idea as the IMDb Top 250 formula, and the antidote to a naive
  /// rating sort.
  Future<List<DiscoveryTitle>> topRatedMovies() async =>
      _map(await _results('/movie/top_rated', const {}), isTv: false);

  // --- Series ----------------------------------------------------------------

  Future<List<DiscoveryTitle>> trendingSeries() async =>
      _map(await _results('/trending/tv/week', const {}), isTv: true);

  Future<List<DiscoveryTitle>> popularSeries() async => _map(
      await _results('/discover/tv', {
        'sort_by': 'popularity.desc',
        'watch_region': region,
        'vote_count.gte': '50',
      }),
      isTv: true);

  Future<List<DiscoveryTitle>> topRatedSeries() async =>
      _map(await _results('/tv/top_rated', const {}), isTv: true);

  /// Cheap credential check for the Settings screen.
  Future<void> verifyKey() async {
    await _results('/configuration', const {});
  }
}
