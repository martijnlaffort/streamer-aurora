import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import '../../core/matching/title_match.dart';
import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/mappers.dart';
import '../sources/canon_source.dart';
import '../sources/playlist_source.dart' show SourceException;
import '../sources/tmdb_source.dart';
import '../sources/wikipedia_trending_source.dart';

/// "Popular" rails that mean something.
///
/// The panel's own `rating` is the only quality signal it gives, and sorting by
/// it is why the old rail was full of unknown titles: a rating with no vote
/// count behind it ranks a film four people loved above a film four million
/// people loved. So ranking comes from outside — TMDB's ranked lists, and a
/// bundled award canon — and this class's job is to work out which of those
/// titles the user's playlist actually carries.
///
/// The resolution is one **streaming pass** over the catalogue, not a lookup per
/// title. Matching ~150 external titles against 150k local rows the naive way is
/// 150 full scans; instead the external titles become an in-memory key map
/// (small) and the catalogue is walked once in pages, keyset-paginated so memory
/// stays flat. Matches are persisted, so rendering a rail afterwards is a single
/// indexed join.
class DiscoveryRepository {
  DiscoveryRepository({
    required this._db,
    required this._canon,
    required this._tmdbFactory,
    WikipediaTrendingSource? wikipedia,
    DateTime Function()? clock,
    this.listTtl = const Duration(hours: 12),
  })  : _wikipedia = wikipedia ?? WikipediaTrendingSource(),
        _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final CanonSource _canon;
  final WikipediaTrendingSource _wikipedia;

  /// Null when no TMDB key is configured — the bundled canon rails still work.
  final TmdbSource? Function() _tmdbFactory;
  final DateTime Function() _clock;
  final Duration listTtl;

  /// Rows read per page while walking the catalogue. Big enough that 150k rows
  /// is ~30 queries, small enough that no page is a memory event.
  static const _scanPage = 5000;

  /// Rails, in the order Home shows them. Bundled canon lists are last: they are
  /// evergreen, so they belong below what is current.
  static const lists = <DiscoveryList>[
    // Wikipedia trending leads, and needs no key: it is the free replacement
    // for TMDB's trending rail, and unlike it, everything here is something
    // people are actually reading about today.
    DiscoveryList(
        id: 'wiki-trending-movie',
        label: 'Trending Today',
        kind: DiscoveryKind.movie,
        needsApiKey: false),
    DiscoveryList(
        id: 'wiki-trending-series',
        label: 'Series People Are Talking About',
        kind: DiscoveryKind.series,
        needsApiKey: false),
    DiscoveryList(
        id: 'tmdb-trending-movie',
        label: 'Trending This Week',
        kind: DiscoveryKind.movie,
        needsApiKey: true),
    DiscoveryList(
        id: 'tmdb-popular-movie',
        // Relabelled per-region at render time — see discoveryRailsProvider.
        label: 'Top 10 Movies',
        kind: DiscoveryKind.movie,
        needsApiKey: true,
        numbered: true),
    DiscoveryList(
        id: 'tmdb-new-movie',
        label: 'New Releases',
        kind: DiscoveryKind.movie,
        needsApiKey: true),
    DiscoveryList(
        id: 'tmdb-trending-series',
        label: 'Trending Series',
        kind: DiscoveryKind.series,
        needsApiKey: true),
    DiscoveryList(
        id: 'tmdb-popular-series',
        label: 'Popular Series',
        kind: DiscoveryKind.series,
        needsApiKey: true),
    DiscoveryList(
        id: 'tmdb-top-movie',
        label: 'Critically Acclaimed',
        kind: DiscoveryKind.movie,
        needsApiKey: true),
    DiscoveryList(
        id: 'tmdb-top-series',
        label: 'Acclaimed Series',
        kind: DiscoveryKind.series,
        needsApiKey: true),
    DiscoveryList(
        id: 'canon-movie',
        label: 'Award Winners',
        kind: DiscoveryKind.movie,
        needsApiKey: false),
    DiscoveryList(
        id: 'canon-series',
        label: 'Award-Winning Series',
        kind: DiscoveryKind.series,
        needsApiKey: false),
  ];

  // --- Refresh ---------------------------------------------------------------

  /// Ensures every available list is present and fresh, then re-resolves them
  /// against [account]'s catalogue. Safe to call on every Home load: it returns
  /// immediately when nothing is stale.
  ///
  /// Failures are contained per list — a TMDB outage or a bad key leaves the
  /// bundled award rails working.
  Future<void> refresh(Account account) async {
    final tmdb = _tmdbFactory();
    var fetchedAnything = false;
    for (final list in lists) {
      if (list.needsApiKey && tmdb == null) continue;
      if (!await _isStale(list.id)) continue;
      try {
        final titles = await _fetch(list, tmdb);
        if (titles.isEmpty) continue;
        await _storeTitles(list, titles);
        fetchedAnything = true;
      } on SourceException catch (e) {
        developer.log('discovery list ${list.id} failed: $e',
            name: 'DiscoveryRepository');
      }
    }
    // Resolve when new lists landed, or when this account has never been
    // resolved (a fresh install, or a catalogue that has since filled in).
    if (fetchedAnything || !await _hasMatches(account)) {
      await resolve(account);
    }
  }

  Future<List<DiscoveryTitle>> _fetch(
      DiscoveryList list, TmdbSource? tmdb) async {
    switch (list.id) {
      case 'tmdb-trending-movie':
        return tmdb!.trendingMovies();
      case 'tmdb-popular-movie':
        return tmdb!.popularMovies();
      case 'tmdb-new-movie':
        return tmdb!.newReleaseMovies();
      case 'tmdb-top-movie':
        return tmdb!.topRatedMovies();
      case 'tmdb-trending-series':
        return tmdb!.trendingSeries();
      case 'tmdb-popular-series':
        return tmdb!.popularSeries();
      case 'tmdb-top-series':
        return tmdb!.topRatedSeries();
      case 'wiki-trending-movie':
        return _wikipedia.trending(series: false);
      case 'wiki-trending-series':
        return _wikipedia.trending(series: true);
      case 'canon-movie':
        return _canon.awardWinningMovies();
      case 'canon-series':
        return _canon.awardWinningSeries();
      default:
        return const [];
    }
  }

  Future<bool> _isStale(String listId) async {
    final row = await (_db.discoveryTitlesTable.select()
          ..where((t) => t.listId.equals(listId))
          ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtMillisUtc)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return true;
    return _clock().difference(fromUtcMillis(row.fetchedAtMillisUtc)) > listTtl;
  }

  Future<void> _storeTitles(
      DiscoveryList list, List<DiscoveryTitle> titles) async {
    final now = utcMillis(_clock());
    await _db.transaction(() async {
      await (_db.discoveryTitlesTable.delete()
            ..where((t) => t.listId.equals(list.id)))
          .go();
      await _db.batch((b) => b.insertAll(
            _db.discoveryTitlesTable,
            [
              for (final t in titles)
                DiscoveryTitlesTableCompanion.insert(
                  listId: list.id,
                  rank: t.rank,
                  kind: list.kind,
                  title: t.title,
                  tmdbId: Value(t.tmdbId),
                  year: Value(t.year),
                  voteAverage: Value(t.voteAverage),
                  voteCount: Value(t.voteCount),
                  fetchedAtMillisUtc: now,
                ),
            ],
          ));
    });
  }

  Future<bool> _hasMatches(Account account) async {
    final row = await (_db.discoveryMatchesTable.select()
          ..where((t) => t.accountId.equals(account.id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  // --- Resolution ------------------------------------------------------------

  /// Walks the catalogue once and records which discovery titles it contains.
  Future<void> resolve(Account account) async {
    final titles = await _db.discoveryTitlesTable.select().get();
    if (titles.isEmpty) return;

    // Key map: normalized title -> the discovery entries wanting it. Built from
    // ~150 short strings, so it is a rounding error in memory next to the
    // catalogue we are about to walk.
    final wanted = <String, List<_Target>>{};
    for (final row in titles) {
      final key = titleKeyFor(row.title, year: row.year);
      if (key.normalized.isEmpty) continue;
      (wanted[key.normalized] ??= []).add(_Target(row.listId, row.rank, row.kind, key));
    }
    if (wanted.isEmpty) return;

    final found = <(String, int), String>{};
    await _scan(account, DiscoveryKind.movie, _db.moviesTable.actualTableName,
        wanted, found);
    await _scan(account, DiscoveryKind.series, _db.seriesTable.actualTableName,
        wanted, found);

    final now = utcMillis(_clock());
    await _db.transaction(() async {
      await (_db.discoveryMatchesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await _db.batch((b) => b.insertAll(
            _db.discoveryMatchesTable,
            [
              for (final entry in found.entries)
                DiscoveryMatchesTableCompanion.insert(
                  accountId: account.id,
                  listId: entry.key.$1,
                  rank: entry.key.$2,
                  localId: entry.value,
                  resolvedAtMillisUtc: now,
                ),
            ],
          ));
    });
    developer.log(
        'discovery resolved ${found.length} matches across ${wanted.length} titles',
        name: 'DiscoveryRepository');
  }

  /// One keyset-paginated pass over a catalogue table. Only id/name/year/poster
  /// are read — never whole rows — and each page is discarded before the next.
  Future<void> _scan(
    Account account,
    DiscoveryKind kind,
    String table,
    Map<String, List<_Target>> wanted,
    Map<(String, int), String> found,
  ) async {
    final accountCol = _db.moviesTable.accountId.name; // same names on all
    final posterCol = _db.moviesTable.posterUrl.name;
    var afterRowId = 0;
    while (true) {
      final page = await _db.customSelect(
        'SELECT rowid AS rid, id AS id, name AS name, year AS year, '
        '$posterCol AS poster FROM $table '
        'WHERE $accountCol = ? AND rowid > ? ORDER BY rowid LIMIT $_scanPage',
        variables: [
          Variable.withString(account.id),
          Variable.withInt(afterRowId),
        ],
      ).get();
      if (page.isEmpty) return;
      for (final row in page) {
        afterRowId = row.read<int>('rid');
        // Build the key once — normalization is year-aware, so a bare
        // normalizeTitle() here would not agree with the key we compare below.
        final localKey = titleKeyFor(row.read<String>('name'),
            year: row.readNullable<int>('year'));
        final targets = wanted[localKey.normalized];
        if (targets == null) continue;
        final hasPoster = row.readNullable<String>('poster') != null;
        for (final target in targets) {
          if (target.kind != kind) continue;
          if (!target.key.matches(localKey)) continue;
          final slot = (target.listId, target.rank);
          // A playlist usually carries the same film several times (qualities,
          // languages). Keep the first hit, but upgrade to one with artwork —
          // a rail of grey placeholders defeats the purpose.
          if (!found.containsKey(slot) || hasPoster) {
            found[slot] = row.read<String>('id');
          }
        }
      }
      // Let the UI breathe between pages; this runs while Home is on screen.
      await Future<void>.delayed(Duration.zero);
    }
  }

  // --- Reads -----------------------------------------------------------------

  /// The resolved movies for a list, in the source list's ranking order.
  Future<List<Movie>> railMovies(Account account, String listId,
      {int limit = 20}) async {
    final ids = await _matchedIds(account, listId, limit);
    if (ids.isEmpty) return const [];
    final rows = await (_db.moviesTable.select()
          ..where((t) => t.accountId.equals(account.id) & t.id.isIn(ids.values)))
        .get();
    final byId = {for (final r in rows) r.id: r.toModel()};
    return [
      for (final id in ids.values)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// The resolved series for a list, in the source list's ranking order.
  Future<List<Series>> railSeries(Account account, String listId,
      {int limit = 20}) async {
    final ids = await _matchedIds(account, listId, limit);
    if (ids.isEmpty) return const [];
    final rows = await (_db.seriesTable.select()
          ..where((t) => t.accountId.equals(account.id) & t.id.isIn(ids.values)))
        .get();
    final byId = {for (final r in rows) r.id: r.toModel()};
    return [
      for (final id in ids.values)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Matched local ids for a list, keyed by rank so ordering survives.
  Future<Map<int, String>> _matchedIds(
      Account account, String listId, int limit) async {
    final rows = await (_db.discoveryMatchesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.listId.equals(listId))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)])
          ..limit(limit))
        .get();
    return {for (final r in rows) r.rank: r.localId};
  }

  /// Drops everything for an account — used when its catalogue is cleared, since
  /// stale matches would point at rows that no longer exist.
  Future<void> clearFor(Account account) =>
      (_db.discoveryMatchesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
}

class _Target {
  const _Target(this.listId, this.rank, this.kind, this.key);

  final String listId;
  final int rank;
  final DiscoveryKind kind;
  final TitleKey key;
}
