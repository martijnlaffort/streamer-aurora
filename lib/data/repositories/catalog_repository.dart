import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/mappers.dart';
import '../sources/playlist_source.dart';

/// DB-side ordering for paged movie reads (the browse grid).
enum MovieOrder { nameAsc, addedDesc, ratingDesc }

/// DB-side ordering for paged series reads.
enum SeriesOrder { nameAsc, ratingDesc }

/// Local-first catalog access (PRD §5, §7, §9): reads are served from drift,
/// the source is only hit when a slice was never fetched or its TTL expired —
/// and TTL refreshes happen in the background while the stale cache is served
/// immediately. When the source is unreachable, the cache is the answer.
class CatalogRepository {
  CatalogRepository({
    required this._db,
    required this._sourceFactory,
    DateTime Function()? clock,
    this.catalogTtl = const Duration(hours: 12),
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final PlaylistSource Function(Account) _sourceFactory;
  final DateTime Function() _clock;
  final Duration catalogTtl;

  /// The most recent fire-and-forget TTL refresh, exposed so tests (and a
  /// future sync UI) can await determinism instead of racing it.
  @visibleForTesting
  Future<void>? lastBackgroundRefresh;

  /// De-dupes concurrent refreshes of the same slice. A single Home load calls
  /// [_ensureFresh] for the same [CatalogKind] many times (categories, the
  /// Popular/Recently rails, every category rail). Without this each call would
  /// kick off its own full-catalog download + parse, and a handful running at
  /// once exhausts memory and gets the app killed by the OS.
  final Map<(String, CatalogKind), Future<void>> _refreshesInFlight = {};

  // --- Refresh machinery -----------------------------------------------------

  /// Force-refreshes catalog slices from the source (all three by default).
  /// Throws [SourceException] on failure — callers decide how to surface it.
  Future<void> refreshCatalog(Account account, {Set<CatalogKind>? kinds}) async {
    for (final kind in kinds ?? CatalogKind.values.toSet()) {
      await _refreshOnce(account, kind);
    }
  }

  /// Refreshes one slice **incrementally**: fetch per category when the source
  /// supports it (Xtream), upsert as we go, and delete no-longer-present rows
  /// at the end. Two hard-won properties on large playlists (tens of
  /// thousands of titles):
  ///
  /// 1. Memory stays flat. A whole-catalog `get_vod_streams` response is tens
  ///    of MB of JSON that balloons ~10× when parsed — a transient spike that
  ///    got the app killed by iOS mid-browse. Per-category responses are small.
  /// 2. The DB is never locked for long. The old delete-all + insert-all
  ///    transaction held drift's connection for 10s+ ("database has been
  ///    locked" warnings), stalling every read — the app felt frozen. Chunked
  ///    upserts release the connection between chunks, and the catalog stays
  ///    complete and browsable throughout (no delete-then-reinsert window).
  Future<void> _refresh(
      Account account, PlaylistSource source, CatalogKind kind) async {
    switch (kind) {
      case CatalogKind.live:
        final categories = await source.getLiveCategories();
        await _replaceCategories(account, CategoryType.live, categories);
        final seen = <String>{};
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final channels =
                await source.getLiveStreams(categoryId: category.id);
            seen.addAll(channels.map((c) => c.id));
            await _upsertChunked(_db.channelsTable,
                [for (final c in channels) c.toCompanion()]);
          }
        } else {
          final channels = await source.getLiveStreams();
          seen.addAll(channels.map((c) => c.id));
          await _upsertChunked(
              _db.channelsTable, [for (final c in channels) c.toCompanion()]);
        }
        await _deleteMissing(
            _db.channelsTable, _db.channelsTable.id, account.id, seen);
        await _touchMeta(account, kind);
      case CatalogKind.vod:
        final categories = await source.getVodCategories();
        await _replaceCategories(account, CategoryType.vod, categories);
        final seen = <String>{};
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final movies = await source.getVodStreams(categoryId: category.id);
            seen.addAll(movies.map((m) => m.id));
            await _upsertChunked(
                _db.moviesTable, [for (final m in movies) m.toCompanion()]);
          }
        } else {
          final movies = await source.getVodStreams();
          seen.addAll(movies.map((m) => m.id));
          await _upsertChunked(
              _db.moviesTable, [for (final m in movies) m.toCompanion()]);
        }
        await _deleteMissing(
            _db.moviesTable, _db.moviesTable.id, account.id, seen);
        await _touchMeta(account, kind);
      case CatalogKind.series:
        final categories = await source.getSeriesCategories();
        await _replaceCategories(account, CategoryType.series, categories);
        final seen = <String>{};
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final series = await source.getSeries(categoryId: category.id);
            seen.addAll(series.map((s) => s.id));
            await _upsertChunked(
                _db.seriesTable, [for (final s in series) s.toCompanion()]);
          }
        } else {
          final series = await source.getSeries();
          seen.addAll(series.map((s) => s.id));
          await _upsertChunked(
              _db.seriesTable, [for (final s in series) s.toCompanion()]);
        }
        await _deleteMissing(
            _db.seriesTable, _db.seriesTable.id, account.id, seen);
        await _touchMeta(account, kind);
    }
  }

  /// Upserts rows in chunks, each in its own short transaction, so catalog
  /// reads interleave instead of queueing behind one giant write.
  Future<void> _upsertChunked<T extends Table, D>(
      TableInfo<T, D> table, List<Insertable<D>> rows) async {
    const chunk = 1000;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = i + chunk < rows.length ? i + chunk : rows.length;
      await _db.batch((b) => b.insertAll(table, rows.sublist(i, end),
          mode: InsertMode.insertOrReplace));
    }
  }

  /// Deletes the account's rows whose id was NOT part of this refresh —
  /// the incremental equivalent of the old delete-all + insert-all, applied
  /// only after all fresh data has landed.
  Future<void> _deleteMissing(TableInfo<Table, dynamic> table,
      GeneratedColumn<String> idColumn, String accountId, Set<String> seen) async {
    final accountCol = _db.moviesTable.accountId.name; // same name on all
    final existing = await _db.customSelect(
      'SELECT ${idColumn.name} AS id FROM ${table.actualTableName} '
      'WHERE $accountCol = ?',
      variables: [Variable.withString(accountId)],
    ).get();
    final stale = [
      for (final row in existing)
        if (!seen.contains(row.read<String>('id'))) row.read<String>('id'),
    ];
    const chunk = 500;
    for (var i = 0; i < stale.length; i += chunk) {
      final end = i + chunk < stale.length ? i + chunk : stale.length;
      final slice = stale.sublist(i, end);
      final placeholders = List.filled(slice.length, '?').join(', ');
      await _db.customStatement(
        'DELETE FROM ${table.actualTableName} '
        'WHERE $accountCol = ? AND ${idColumn.name} IN ($placeholders)',
        [accountId, ...slice],
      );
    }
  }

  Future<void> _replaceCategories(
      Account account, CategoryType type, List<Category> categories) async {
    await (_db.categoriesTable.delete()
          ..where((t) => t.accountId.equals(account.id) & t.type.equalsValue(type)))
        .go();
    await _db.batch((b) => b.insertAll(
        _db.categoriesTable, categories.map((c) => c.toCompanion())));
  }

  Future<void> _touchMeta(Account account, CatalogKind kind) =>
      _db.catalogMetaTable.insertOnConflictUpdate(
        CatalogMetaTableCompanion.insert(
          accountId: account.id,
          kind: kind,
          refreshedAtMillisUtc: utcMillis(_clock()),
        ),
      );

  /// Never fetched → fetch now (propagating failures: there is nothing to
  /// serve). Stale → serve cache and refresh in the background, swallowing
  /// failures (the cache remains the answer — the offline case).
  Future<void> _ensureFresh(Account account, CatalogKind kind) async {
    final meta = await (_db.catalogMetaTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.kind.equalsValue(kind)))
        .getSingleOrNull();
    if (meta == null) {
      // Never fetched: block on the (de-duped) refresh — there's nothing to
      // serve until it lands.
      await _refreshOnce(account, kind);
      return;
    }
    final age = _clock().difference(fromUtcMillis(meta.refreshedAtMillisUtc));
    if (age > catalogTtl) {
      final refresh = _refreshOnce(account, kind).catchError((Object e) =>
          developer.log('background refresh of $kind failed: $e',
              name: 'CatalogRepository'));
      lastBackgroundRefresh = refresh;
      unawaited(refresh);
    }
  }

  /// Runs at most one [_refresh] per (account, slice) at a time; concurrent
  /// callers share the single in-flight future instead of each starting their
  /// own full-catalog download. Cleared on completion (success or failure) so
  /// the next post-TTL refresh can run.
  Future<void> _refreshOnce(Account account, CatalogKind kind) {
    final key = (account.id, kind);
    final existing = _refreshesInFlight[key];
    if (existing != null) return existing;
    final future = _serialized(() =>
            _refresh(account, _sourceFactory(account), kind))
        .whenComplete(() {
      // MUST stay a block body. `() => map.remove(key)` RETURNS the removed
      // value — this very future — and whenComplete awaits a returned future,
      // so the future would wait on itself and never complete. That exact
      // deadlock shipped once: every awaiting read hung forever while the
      // refresh work still ran ("the app is really slow").
      _refreshesInFlight.remove(key);
    });
    _refreshesInFlight[key] = future;
    return future;
  }

  /// Serializes refreshes ACROSS slices too: at Home load, live/vod/series can
  /// all go stale together, and even per-category downloads for two slices at
  /// once doubles the transient memory. One at a time keeps the peak flat.
  Future<void> _refreshTail = Future<void>.value();
  Future<void> _serialized(Future<void> Function() job) {
    final run = _refreshTail.then((_) => job());
    // The chain must survive failures; errors still reach this job's awaiters.
    _refreshTail = run.catchError((Object _) {});
    return run;
  }

  // --- Reads (cache-backed, paged) -------------------------------------------

  Future<List<Category>> categories(Account account, CategoryType type) async {
    await _ensureFresh(account, _kindOf(type));
    final rows = await (_db.categoriesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.type.equalsValue(type))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  CatalogKind _kindOf(CategoryType type) => switch (type) {
        CategoryType.live => CatalogKind.live,
        CategoryType.vod => CatalogKind.vod,
        CategoryType.series => CatalogKind.series,
      };

  Future<List<Channel>> channels(
    Account account, {
    String? categoryId,
    int? limit,
    int offset = 0,
  }) async {
    await _ensureFresh(account, CatalogKind.live);
    final query = _db.channelsTable.select()
      ..where((t) => t.accountId.equals(account.id))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    if (limit != null) query.limit(limit, offset: offset);
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  Future<List<Movie>> movies(
    Account account, {
    String? categoryId,
    Set<String>? categoryIds,
    MovieOrder order = MovieOrder.nameAsc,
    int? limit,
    int offset = 0,
  }) async {
    // Content-language filter on the unscoped list with no allowed categories
    // → nothing (skip the query).
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return [];
    }
    await _ensureFresh(account, CatalogKind.vod);
    final query = _db.moviesTable.select()
      ..where((t) => t.accountId.equals(account.id));
    switch (order) {
      case MovieOrder.nameAsc:
        query.orderBy([(t) => OrderingTerm.asc(t.name)]);
      case MovieOrder.addedDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.addedAtMillisUtc)]);
      case MovieOrder.ratingDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.rating)]);
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    } else if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    if (limit != null) query.limit(limit, offset: offset);
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  Future<List<Series>> series(
    Account account, {
    String? categoryId,
    Set<String>? categoryIds,
    SeriesOrder order = SeriesOrder.nameAsc,
    int? limit,
    int offset = 0,
  }) async {
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return [];
    }
    await _ensureFresh(account, CatalogKind.series);
    final query = _db.seriesTable.select()
      ..where((t) => t.accountId.equals(account.id));
    switch (order) {
      case SeriesOrder.nameAsc:
        query.orderBy([(t) => OrderingTerm.asc(t.name)]);
      case SeriesOrder.ratingDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.rating)]);
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    } else if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    if (limit != null) query.limit(limit, offset: offset);
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  /// Newest movies, sorted and limited in SQL (for the Home hero +
  /// "Recently Added" rail). Restricted to [categoryIds] when the
  /// content-language filter is on. Sorting/limiting here — rather than
  /// loading the whole catalog into Dart and sorting in memory — keeps Home's
  /// footprint tiny on large playlists. NULL `addedAt` sorts last (as before).
  Future<List<Movie>> recentMovies(
    Account account, {
    required int limit,
    Set<String>? categoryIds,
  }) async {
    if (categoryIds != null && categoryIds.isEmpty) return [];
    await _ensureFresh(account, CatalogKind.vod);
    final query = _db.moviesTable.select()
      ..where((t) => t.accountId.equals(account.id))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAtMillisUtc)])
      ..limit(limit);
    if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  /// Highest-rated movies, sorted and limited in SQL (the Home "Popular"
  /// rail). Only rated titles (rating > 0) qualify; empty when the panel
  /// provides no ratings.
  Future<List<Movie>> topRatedMovies(
    Account account, {
    required int limit,
    Set<String>? categoryIds,
  }) async {
    if (categoryIds != null && categoryIds.isEmpty) return [];
    await _ensureFresh(account, CatalogKind.vod);
    final query = _db.moviesTable.select()
      ..where((t) =>
          t.accountId.equals(account.id) & t.rating.isBiggerThanValue(0.0))
      ..orderBy([(t) => OrderingTerm.desc(t.rating)])
      ..limit(limit);
    if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  /// Highest-rated series, sorted and limited in SQL (the Home "Popular" rail).
  Future<List<Series>> topRatedSeries(
    Account account, {
    required int limit,
    Set<String>? categoryIds,
  }) async {
    if (categoryIds != null && categoryIds.isEmpty) return [];
    await _ensureFresh(account, CatalogKind.series);
    final query = _db.seriesTable.select()
      ..where((t) =>
          t.accountId.equals(account.id) & t.rating.isBiggerThanValue(0.0))
      ..orderBy([(t) => OrderingTerm.desc(t.rating)])
      ..limit(limit);
    if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  /// Cache-only single-row lookup (no source contact) — for resolving
  /// content keys (Continue Watching, favorites) and detail routes.
  Future<Movie?> movieById(Account account, String movieId) async {
    final row = await (_db.moviesTable.select()
          ..where((t) => t.accountId.equals(account.id) & t.id.equals(movieId)))
        .getSingleOrNull();
    return row?.toModel();
  }

  /// Cache-only single-row lookup (no source contact).
  Future<Series?> seriesById(Account account, String seriesId) async {
    final row = await (_db.seriesTable.select()
          ..where((t) => t.accountId.equals(account.id) & t.id.equals(seriesId)))
        .getSingleOrNull();
    return row?.toModel();
  }

  /// Cache-only single episode lookup — resolves a watched episode back to its
  /// series (for Continue Watching). Present whenever the series detail was
  /// opened, which is the only way to reach an episode.
  Future<Episode?> episodeById(Account account, String episodeId) async {
    final row = await (_db.episodesTable.select()
          ..where(
              (t) => t.accountId.equals(account.id) & t.id.equals(episodeId)))
        .getSingleOrNull();
    return row?.toModel();
  }

  /// Cache-only single-row lookup (no source contact).
  Future<Channel?> channelById(Account account, String channelId) async {
    final row = await (_db.channelsTable.select()
          ..where(
              (t) => t.accountId.equals(account.id) & t.id.equals(channelId)))
        .getSingleOrNull();
    return row?.toModel();
  }

  // --- Search (cache-only — instant, PRD §8.6) -------------------------------

  Future<List<Movie>> searchMovies(Account account, String query,
      {int limit = 30}) async {
    final rows = await (_db.moviesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.name.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Series>> searchSeries(Account account, String query,
      {int limit = 30}) async {
    final rows = await (_db.seriesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.name.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Channel>> searchChannels(Account account, String query,
      {int limit = 30}) async {
    final rows = await (_db.channelsTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.name.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  // --- Cache maintenance (PRD §8.12) -----------------------------------------

  Future<({int channels, int movies, int series, int episodes})> cacheStats(
      Account account) async {
    Future<int> countOf(TableInfo table, Expression<bool> where) async {
      final count = countAll();
      final query = _db.selectOnly(table)
        ..addColumns([count])
        ..where(where);
      final row = await query.getSingle();
      return row.read(count) ?? 0;
    }

    return (
      channels:
          await countOf(_db.channelsTable, _db.channelsTable.accountId.equals(account.id)),
      movies:
          await countOf(_db.moviesTable, _db.moviesTable.accountId.equals(account.id)),
      series:
          await countOf(_db.seriesTable, _db.seriesTable.accountId.equals(account.id)),
      episodes: await countOf(
          _db.episodesTable, _db.episodesTable.accountId.equals(account.id)),
    );
  }

  /// Drops the cached catalog (not progress/favorites); the next read
  /// refetches from the source.
  Future<void> clearCatalogCache(Account account) async {
    await _db.transaction(() async {
      await (_db.categoriesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.channelsTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.moviesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.seriesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.episodesTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.epgCacheTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
      await (_db.catalogMetaTable.delete()
            ..where((t) => t.accountId.equals(account.id)))
          .go();
    });
  }

  // --- Details (enrich cache; serve cache offline) ---------------------------

  /// Full VOD detail: fetches from the source and folds the richer fields
  /// into the cached row; serves the cached row when the source is down.
  Future<Movie> movieDetail(Account account, String movieId) async {
    try {
      final detail = await _sourceFactory(account).getVodInfo(movieId);
      await _db.moviesTable.insertOnConflictUpdate(detail.toCompanion());
      return detail;
    } on SourceException {
      final row = await (_db.moviesTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) & t.id.equals(movieId)))
          .getSingleOrNull();
      if (row == null) rethrow;
      return row.toModel();
    }
  }

  /// Seasons + episodes: fetched and cached; rebuilt from cache offline.
  Future<SeriesDetail> seriesDetail(Account account, String seriesId) async {
    try {
      final detail = await _sourceFactory(account).getSeriesInfo(seriesId);
      await _db.transaction(() async {
        await _db.seriesTable.insertOnConflictUpdate(detail.series.toCompanion());
        await (_db.episodesTable.delete()
              ..where((t) =>
                  t.accountId.equals(account.id) & t.seriesId.equals(seriesId)))
            .go();
        await _db.batch((b) => b.insertAll(_db.episodesTable,
            detail.episodes.map((e) => e.toCompanion(accountId: account.id))));
      });
      return detail;
    } on SourceException {
      final seriesRow = await (_db.seriesTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) & t.id.equals(seriesId)))
          .getSingleOrNull();
      if (seriesRow == null) rethrow;
      final episodeRows = await (_db.episodesTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) & t.seriesId.equals(seriesId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.seasonNumber),
              (t) => OrderingTerm.asc(t.episodeNumber),
            ]))
          .get();
      final episodes = episodeRows.map((r) => r.toModel()).toList();
      final seasonNumbers = episodes.map((e) => e.seasonNumber).toSet().toList()
        ..sort();
      return SeriesDetail(
        series: seriesRow.toModel(),
        seasons: [
          for (final n in seasonNumbers)
            Season(id: '$seriesId-s$n', seriesId: seriesId, seasonNumber: n),
        ],
        episodes: episodes,
      );
    }
  }

}

