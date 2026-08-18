import 'package:dawnplayer/data/sources/playlist_source.dart';
import 'package:dawnplayer/domain/models/models.dart';

/// Canned-data source for repository tests. Set [offline] to simulate an
/// unreachable panel; every call is counted in [calls].
class FakePlaylistSource implements PlaylistSource {
  FakePlaylistSource({
    required this.accountId,
    required this._clock,
  });

  final String accountId;
  final DateTime Function() _clock;

  bool offline = false;
  final Map<String, int> calls = {};

  /// Mutable so tests can change what a refresh returns.
  late List<Movie> vodStreams = [
    Movie(
      id: '1001',
      accountId: accountId,
      categoryId: 'c-vod',
      name: 'Beta Movie',
      rating: 7.5,
      containerExt: 'mkv',
      cachedAt: _clock(),
    ),
    Movie(
      id: '1002',
      accountId: accountId,
      categoryId: 'c-vod',
      name: 'Alpha Movie',
      cachedAt: _clock(),
    ),
  ];

  void _guard(String name) {
    calls[name] = (calls[name] ?? 0) + 1;
    if (offline) throw const SourceException('offline (fake)');
  }

  @override
  bool get supportsCategoryFetch => false;

  @override
  Future<void> authenticate() async => _guard('authenticate');

  @override
  Future<List<Category>> getLiveCategories() async {
    _guard('getLiveCategories');
    return [
      Category(id: 'c-live', accountId: accountId, type: CategoryType.live, name: 'Live', sortOrder: 0),
    ];
  }

  @override
  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    _guard('getLiveStreams');
    return [
      Channel(id: 'ch1', accountId: accountId, categoryId: 'c-live', name: 'One', epgChannelId: 'one.epg', sortOrder: 1, cachedAt: _clock()),
      Channel(id: 'ch2', accountId: accountId, categoryId: 'c-live', name: 'Two', sortOrder: 2, cachedAt: _clock()),
      Channel(id: 'ch3', accountId: accountId, categoryId: 'c-live', name: 'Three', sortOrder: 3, cachedAt: _clock()),
    ];
  }

  @override
  Future<List<Category>> getVodCategories() async {
    _guard('getVodCategories');
    return [
      Category(id: 'c-vod', accountId: accountId, type: CategoryType.vod, name: 'Movies', sortOrder: 0),
    ];
  }

  @override
  Future<List<Movie>> getVodStreams({String? categoryId}) async {
    _guard('getVodStreams');
    return vodStreams;
  }

  @override
  Future<Movie> getVodInfo(String vodId) async {
    _guard('getVodInfo');
    return Movie(
      id: vodId,
      accountId: accountId,
      categoryId: 'c-vod',
      name: 'Beta Movie',
      plot: 'Enriched plot from the panel.',
      genre: 'Drama',
      cast: 'Actor A',
      durationSeconds: 5400,
      rating: 7.5,
      containerExt: 'mkv',
      cachedAt: _clock(),
    );
  }

  @override
  Future<List<Category>> getSeriesCategories() async {
    _guard('getSeriesCategories');
    return [
      Category(id: 'c-series', accountId: accountId, type: CategoryType.series, name: 'Shows', sortOrder: 0),
    ];
  }

  @override
  Future<List<Series>> getSeries({String? categoryId}) async {
    _guard('getSeries');
    return [
      Series(id: 's15', accountId: accountId, categoryId: 'c-series', name: 'Fake Show', cachedAt: _clock()),
    ];
  }

  @override
  Future<SeriesDetail> getSeriesInfo(String seriesId) async {
    _guard('getSeriesInfo');
    final episodes = [
      Episode(id: 'e1', seriesId: seriesId, seasonNumber: 1, episodeNumber: 1, title: 'Pilot', cachedAt: _clock()),
      Episode(id: 'e2', seriesId: seriesId, seasonNumber: 1, episodeNumber: 2, title: 'Second', cachedAt: _clock()),
      Episode(id: 'e3', seriesId: seriesId, seasonNumber: 2, episodeNumber: 1, title: 'Return', cachedAt: _clock()),
    ];
    return SeriesDetail(
      series: Series(id: seriesId, accountId: accountId, categoryId: 'c-series', name: 'Fake Show', plot: 'Enriched.', cachedAt: _clock()),
      seasons: [
        Season(id: 's1', seriesId: seriesId, seasonNumber: 1),
        Season(id: 's2', seriesId: seriesId, seasonNumber: 2),
      ],
      episodes: episodes,
    );
  }

  @override
  Future<List<EpgEntry>> getShortEpg(String streamId, {int limit = 4}) async {
    _guard('getShortEpg');
    final base = DateTime.utc(2026, 1, 1, 20);
    return [
      EpgEntry(channelId: 'one.epg', start: base, stop: base.add(const Duration(hours: 1)), title: 'Now Show'),
      EpgEntry(channelId: 'one.epg', start: base.add(const Duration(hours: 1)), stop: base.add(const Duration(hours: 2)), title: 'Next Show'),
    ];
  }

  @override
  Future<String> buildStreamUrl(StreamRef ref) async =>
      'http://fake/${ref.type.name}/${ref.streamId}';

  /// Null → EPG falls back to per-channel getShortEpg; set to exercise the
  /// bulk-XMLTV ingestion path.
  String? xmltv;

  @override
  String? get xmltvUrl => xmltv;
}
