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
  /// This is the only remaining *whole-slice* sweep and it exists for explicit
  /// user action (pull-to-refresh, Settings → refresh). Routine freshness is
  /// per-category and on demand — see [_ensureCategoryFresh].
  ///
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
        await _beginSeen();
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final channels =
                await source.getLiveStreams(categoryId: category.id);
            await _upsertChunked(_db.channelsTable,
                [for (final c in channels) c.toCompanion()]);
            await _markSeen(channels.map((c) => c.id));
            await _touchCategoryMeta(account, kind, category.id);
          }
        } else {
          final channels = await source.getLiveStreams();
          await _upsertChunked(
              _db.channelsTable, [for (final c in channels) c.toCompanion()]);
          await _markSeen(channels.map((c) => c.id));
        }
        await _deleteUnseen(
            _db.channelsTable, _db.channelsTable.id, account.id);
        await _touchMeta(account, kind);
      case CatalogKind.vod:
        final categories = await source.getVodCategories();
        await _replaceCategories(account, CategoryType.vod, categories);
        await _beginSeen();
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final movies = await source.getVodStreams(categoryId: category.id);
            await _upsertChunked(
                _db.moviesTable, [for (final m in movies) m.toCompanion()]);
            await _markSeen(movies.map((m) => m.id));
            await _touchCategoryMeta(account, kind, category.id);
          }
        } else {
          final movies = await source.getVodStreams();
          await _upsertChunked(
              _db.moviesTable, [for (final m in movies) m.toCompanion()]);
          await _markSeen(movies.map((m) => m.id));
        }
        await _deleteUnseen(_db.moviesTable, _db.moviesTable.id, account.id);
        await _touchMeta(account, kind);
      case CatalogKind.series:
        final categories = await source.getSeriesCategories();
        await _replaceCategories(account, CategoryType.series, categories);
        await _beginSeen();
        if (source.supportsCategoryFetch && categories.isNotEmpty) {
          for (final category in categories) {
            final series = await source.getSeries(categoryId: category.id);
            await _upsertChunked(
                _db.seriesTable, [for (final s in series) s.toCompanion()]);
            await _markSeen(series.map((s) => s.id));
            await _touchCategoryMeta(account, kind, category.id);
          }
        } else {
          final series = await source.getSeries();
          await _upsertChunked(
              _db.seriesTable, [for (final s in series) s.toCompanion()]);
          await _markSeen(series.map((s) => s.id));
        }
        await _deleteUnseen(_db.seriesTable, _db.seriesTable.id, account.id);
        await _touchMeta(account, kind);
    }
  }

  /// Upserts rows in chunks, each in its own short transaction, so catalog
  /// reads interleave instead of queueing behind one giant write.
  ///
  /// The chunk is deliberately modest: every statement drift sends shares one
  /// serialized connection, so a browse query issued mid-chunk waits for that
  /// whole chunk to commit. Smaller chunks bound how long a tap can stall — the
  /// throughput difference over a refresh is nil next to the network time.
  Future<void> _upsertChunked<T extends Table, D>(
      TableInfo<T, D> table, List<Insertable<D>> rows) async {
    // 500, not smaller: each chunk is its own transaction, so halving the chunk
    // doubles the commits (and their fsyncs) across the refresh. This is the
    // point where a stalled tap is short without the refresh itself dragging.
    const chunk = 500;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = i + chunk < rows.length ? i + chunk : rows.length;
      await _db.batch((b) => b.insertAll(table, rows.sublist(i, end),
          mode: InsertMode.insertOrReplace));
      // Hand the event loop back between chunks so queued UI work (a category
      // tap, a rail read) gets its turn instead of waiting out the whole slice.
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The ids seen so far in the running refresh, held in SQLite rather than in
  /// a Dart `Set`.
  ///
  /// This used to be a `Set<String>` plus a `SELECT` of every cached id to diff
  /// against it. On a large line (150k titles) that is every id in memory twice
  /// over — tens of MB and seconds of main-isolate time to decode, on the
  /// device that is already tight on both, right at the end of a refresh the
  /// user is browsing through. The anti-join below does the same work entirely
  /// inside the database isolate, and nothing but ids ever crosses the port.
  ///
  /// One temp table is enough because [_serialized] runs at most one refresh at
  /// a time; it is dropped up front so an earlier failed refresh can't leak
  /// ids into this one.
  Future<void> _beginSeen() async {
    await _db.customStatement('DROP TABLE IF EXISTS temp.refresh_seen');
    await _db.customStatement(
        'CREATE TEMPORARY TABLE refresh_seen (id TEXT NOT NULL PRIMARY KEY)');
  }

  /// One transaction for the whole batch of ids: these are bookkeeping writes to
  /// a temp table, and committing every chunk separately would add an fsync per
  /// 500 ids across the entire catalog for no durability benefit.
  Future<void> _markSeen(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return;
    await _db.transaction(() async {
      const chunk = 500;
      for (var i = 0; i < list.length; i += chunk) {
        final end = i + chunk < list.length ? i + chunk : list.length;
        final slice = list.sublist(i, end);
        final values = List.filled(slice.length, '(?)').join(', ');
        await _db.customStatement(
            'INSERT OR IGNORE INTO temp.refresh_seen (id) VALUES $values',
            slice);
      }
    });
  }

  /// Deletes the account's rows whose id was NOT part of this refresh — the
  /// incremental equivalent of the old delete-all + insert-all, applied only
  /// after all fresh data has landed.
  Future<void> _deleteUnseen(TableInfo<Table, dynamic> table,
      GeneratedColumn<String> idColumn, String accountId) async {
    final accountCol = _db.moviesTable.accountId.name; // same name on all
    await _db.customStatement(
      'DELETE FROM ${table.actualTableName} WHERE $accountCol = ? '
      'AND ${idColumn.name} NOT IN (SELECT id FROM temp.refresh_seen)',
      [accountId],
    );
    await _db.customStatement('DROP TABLE IF EXISTS temp.refresh_seen');
  }

  /// As [_deleteUnseen], but scoped to one category — the per-category refresh
  /// only has authority over its own category's rows.
  Future<void> _deleteUnseenInCategory(TableInfo<Table, dynamic> table,
      GeneratedColumn<String> idColumn, String accountId, String categoryId) async {
    final accountCol = _db.moviesTable.accountId.name; // same names on all
    final categoryCol = _db.moviesTable.categoryId.name;
    await _db.customStatement(
      'DELETE FROM ${table.actualTableName} '
      'WHERE $accountCol = ? AND $categoryCol = ? '
      'AND ${idColumn.name} NOT IN (SELECT id FROM temp.refresh_seen)',
      [accountId, categoryId],
    );
    await _db.customStatement('DROP TABLE IF EXISTS temp.refresh_seen');
  }

  // --- Per-category refresh (the routine path) -------------------------------

  /// Fetches ONE category's items. This is the unit of refresh for panels that
  /// support `category_id` (Xtream): a single request, a few hundred to a few
  /// thousand rows, done in a second or so. Sweeping every category of a big
  /// line instead is minutes of network and hundreds of write transactions that
  /// starve every read the user makes in the meantime.
  Future<void> _refreshCategory(Account account, PlaylistSource source,
      CatalogKind kind, String categoryId) async {
    await _beginSeen();
    switch (kind) {
      case CatalogKind.live:
        final channels = await source.getLiveStreams(categoryId: categoryId);
        await _upsertChunked(
            _db.channelsTable, [for (final c in channels) c.toCompanion()]);
        await _markSeen(channels.map((c) => c.id));
        await _deleteUnseenInCategory(
            _db.channelsTable, _db.channelsTable.id, account.id, categoryId);
      case CatalogKind.vod:
        final movies = await source.getVodStreams(categoryId: categoryId);
        await _upsertChunked(
            _db.moviesTable, [for (final m in movies) m.toCompanion()]);
        await _markSeen(movies.map((m) => m.id));
        await _deleteUnseenInCategory(
            _db.moviesTable, _db.moviesTable.id, account.id, categoryId);
      case CatalogKind.series:
        final series = await source.getSeries(categoryId: categoryId);
        await _upsertChunked(
            _db.seriesTable, [for (final s in series) s.toCompanion()]);
        await _markSeen(series.map((s) => s.id));
        await _deleteUnseenInCategory(
            _db.seriesTable, _db.seriesTable.id, account.id, categoryId);
    }
    await _touchCategoryMeta(account, kind, categoryId);
  }

  /// De-dupes concurrent refreshes of the same category: Home can ask for the
  /// same category from several rails at once.
  final Map<(String, CatalogKind, String), Future<void>>
      _categoryRefreshesInFlight = {};

  Future<void> _refreshCategoryOnce(
      Account account, CatalogKind kind, String categoryId) {
    final key = (account.id, kind, categoryId);
    final existing = _categoryRefreshesInFlight[key];
    if (existing != null) return existing;
    final future = _serialized(() => _refreshCategory(
        account, _sourceFactory(account), kind, categoryId)).whenComplete(() {
      // MUST stay a block body — see the note in [_refreshOnce].
      _categoryRefreshesInFlight.remove(key);
    });
    _categoryRefreshesInFlight[key] = future;
    return future;
  }

  /// Most categories that may be queued for a warm before further requests are
  /// dropped. A category-rails screen can ask for hundreds as the user scrolls;
  /// beyond a handful the user has already scrolled past them, and warming a
  /// category is not cheap — the panel has no per-category limit, so it pulls
  /// the *whole* category (megabytes on a large line) to fill one rail.
  static const _maxQueuedWarms = 4;

  /// Fetches one category into the cache if it is missing or stale, for a caller
  /// that will NOT wait on it (the rails). Returns immediately when the category
  /// is already fresh, or when too many warms are already queued.
  ///
  /// Awaiting the returned future is fine and is what a rail with nothing to
  /// show does; a rail that already has cached rows fires and forgets.
  Future<void> warmCategory(
      Account account, CatalogKind kind, String categoryId) async {
    if (!_supportsCategoryFetch(account)) return;
    final key = (account.id, kind, categoryId);
    // Already running → join it rather than dropping; it costs nothing extra.
    final inFlight = _categoryRefreshesInFlight[key];
    if (inFlight != null) return inFlight;
    final meta = await (_db.catalogCategoryMetaTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              t.kind.equalsValue(kind) &
              t.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (meta != null &&
        _clock().difference(fromUtcMillis(meta.refreshedAtMillisUtc)) <=
            catalogTtl) {
      return; // Fresh.
    }
    if (_categoryRefreshesInFlight.length >= _maxQueuedWarms) return;
    await _refreshCategoryOnce(account, kind, categoryId);
  }

  /// Whether this account's panel can fetch a single category. Cached because
  /// every read consults it and building a source allocates an HTTP client.
  final Map<String, bool> _categoryFetchSupport = {};
  bool _supportsCategoryFetch(Account account) => _categoryFetchSupport
      .putIfAbsent(account.id, () => _sourceFactory(account).supportsCategoryFetch);

  /// Freshness for a read scoped to one category, on the one rule that matters
  /// for how the app feels: **never block when there is something to show.**
  ///
  /// Cached rows for this category → serve them and refresh it behind the
  /// screen. Nothing cached → fetch it now, because the alternative is an empty
  /// screen; that is one request for one category, not a catalog sweep.
  ///
  /// Blocking whenever the per-category TTL was merely *missing* is what made
  /// Home crawl: its six category rails each waited on their own fetch.
  Future<void> _ensureCategoryFresh(
      Account account, CatalogKind kind, String categoryId) async {
    if (!_supportsCategoryFetch(account)) {
      // One-file sources (M3U) have no per-category fetch; the slice is the unit.
      return _ensureFresh(account, kind);
    }
    final meta = await (_db.catalogCategoryMetaTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              t.kind.equalsValue(kind) &
              t.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (meta != null &&
        _clock().difference(fromUtcMillis(meta.refreshedAtMillisUtc)) <=
            catalogTtl) {
      return; // Fresh.
    }
    final refresh = _refreshCategoryOnce(account, kind, categoryId);
    if (await _hasCachedItems(account, kind, categoryId: categoryId)) {
      final background = refresh.catchError((Object e) => developer.log(
          'background refresh of $kind/$categoryId failed: $e',
          name: 'CatalogRepository'));
      lastBackgroundRefresh = background;
      unawaited(background);
      return;
    }
    await refresh; // Nothing to show — propagate failures.
  }

  /// Freshness for the category *list* of a slice — one cheap request, and the
  /// thing the browse chips and Home's rails are built from.
  Future<void> _ensureCategoryListFresh(
      Account account, CatalogKind kind) async {
    if (!_supportsCategoryFetch(account)) return _ensureFresh(account, kind);
    final meta = await (_db.catalogMetaTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.kind.equalsValue(kind)))
        .getSingleOrNull();
    if (meta == null) {
      await _refreshListOnce(account, kind);
      return;
    }
    final age = _clock().difference(fromUtcMillis(meta.refreshedAtMillisUtc));
    if (age > catalogTtl) {
      final refresh = _refreshListOnce(account, kind).catchError((Object e) =>
          developer.log('background refresh of $kind categories failed: $e',
              name: 'CatalogRepository'));
      lastBackgroundRefresh = refresh;
      unawaited(refresh);
    }
  }

  final Map<(String, CatalogKind), Future<void>> _listRefreshesInFlight = {};

  Future<void> _refreshListOnce(Account account, CatalogKind kind) {
    final key = (account.id, kind);
    final existing = _listRefreshesInFlight[key];
    if (existing != null) return existing;
    final future = _serialized(() async {
      final source = _sourceFactory(account);
      final type = _typeOf(kind);
      final categories = switch (kind) {
        CatalogKind.live => await source.getLiveCategories(),
        CatalogKind.vod => await source.getVodCategories(),
        CatalogKind.series => await source.getSeriesCategories(),
      };
      await _replaceCategories(account, type, categories);
      await _touchMeta(account, kind);
    }).whenComplete(() {
      // MUST stay a block body — see the note in [_refreshOnce].
      _listRefreshesInFlight.remove(key);
    });
    _listRefreshesInFlight[key] = future;
    return future;
  }

  /// How many categories a brand-new account seeds before browsing takes over.
  static const _bootstrapCategories = 6;

  /// Freshness for reads that span categories — the "All" grid and Home's
  /// hero/Popular rails. These cannot pull 200k items, so they are served from
  /// cache; the per-category reads behind the browse chips and the category
  /// rails are what keep the cache current.
  ///
  /// The exception is a brand-new account, where the cache is empty and serving
  /// it would show an empty app: seed a bounded number of categories so there
  /// is something to open, and let browsing fill in the rest.
  Future<void> _ensureSliceBootstrapped(
      Account account, CatalogKind kind) async {
    if (!_supportsCategoryFetch(account)) return _ensureFresh(account, kind);
    await _ensureCategoryListFresh(account, kind);
    final seeded = await (_db.catalogCategoryMetaTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.kind.equalsValue(kind))
          ..limit(1))
        .getSingleOrNull();
    if (seeded != null) return; // Already seeded — the cache is the answer.
    // No per-category TTLs recorded yet. If the slice nonetheless holds rows —
    // an upgrade from the build that swept whole slices, or an explicit
    // refreshCatalog() — serve them and seed in the background. Blocking here
    // would stall a screen we can already fill, which is the whole complaint.
    final seed = _seedOnce(account, kind);
    if (await _hasCachedItems(account, kind)) {
      final background = seed.catchError((Object e) => developer.log(
          'background seed of $kind failed: $e', name: 'CatalogRepository'));
      lastBackgroundRefresh = background;
      unawaited(background);
      return;
    }
    await seed; // Genuinely nothing to show — propagate failures.
  }

  /// Whether anything is cached for a slice, or for one category of it.
  /// Gets a slice ready for first use after an account is added: fetch the
  /// category list, then seed a bounded number of categories.
  ///
  /// Explicitly NOT [refreshCatalog]. Onboarding used to sweep every slice in
  /// full, which on a large line is 200k+ items — minutes of waiting before the
  /// app opens, and the exact operation that used to get it killed for memory.
  /// Browsing fills in the rest per category, on demand.
  Future<void> prepareSlice(Account account, CatalogKind kind) =>
      _ensureSliceBootstrapped(account, kind);

  Future<bool> _hasCachedItems(Account account, CatalogKind kind,
      {String? categoryId}) async {
    final table = switch (kind) {
      CatalogKind.live => _db.channelsTable.actualTableName,
      CatalogKind.vod => _db.moviesTable.actualTableName,
      CatalogKind.series => _db.seriesTable.actualTableName,
    };
    final accountCol = _db.moviesTable.accountId.name; // same names on all
    final categoryCol = _db.moviesTable.categoryId.name;
    final rows = await _db.customSelect(
      'SELECT 1 FROM $table WHERE $accountCol = ?'
      '${categoryId == null ? '' : ' AND $categoryCol = ?'} LIMIT 1',
      variables: [
        Variable.withString(account.id),
        if (categoryId != null) Variable.withString(categoryId),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  final Map<(String, CatalogKind), Future<void>> _seedsInFlight = {};

  /// Seeds the first few categories of a slice, once per (account, slice) —
  /// Home asks several times over (hero, Popular, Recently) and they should
  /// share one seed rather than each starting their own.
  Future<void> _seedOnce(Account account, CatalogKind kind) {
    final key = (account.id, kind);
    final existing = _seedsInFlight[key];
    if (existing != null) return existing;
    final future = Future(() async {
      final categories = await (_db.categoriesTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) &
                t.type.equalsValue(_typeOf(kind)))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
            ..limit(_bootstrapCategories))
          .get();
      for (final category in categories) {
        await _refreshCategoryOnce(account, kind, category.id);
      }
    }).whenComplete(() {
      // MUST stay a block body — see the note in [_refreshOnce].
      _seedsInFlight.remove(key);
    });
    _seedsInFlight[key] = future;
    return future;
  }

  Future<void> _touchCategoryMeta(
          Account account, CatalogKind kind, String categoryId) =>
      _db.catalogCategoryMetaTable.insertOnConflictUpdate(
        CatalogCategoryMetaTableCompanion.insert(
          accountId: account.id,
          kind: kind,
          categoryId: categoryId,
          refreshedAtMillisUtc: utcMillis(_clock()),
        ),
      );

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
    await _ensureCategoryListFresh(account, _kindOf(type));
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

  CategoryType _typeOf(CatalogKind kind) => switch (kind) {
        CatalogKind.live => CategoryType.live,
        CatalogKind.vod => CategoryType.vod,
        CatalogKind.series => CategoryType.series,
      };

  /// Paged channel read. [categoryIds] restricts the unscoped list to the
  /// content-language-allowed categories — in SQL, because filtering *after*
  /// the limit would hand the caller short pages.
  Future<List<Channel>> channels(
    Account account, {
    String? categoryId,
    Set<String>? categoryIds,
    int? limit,
    int offset = 0,
  }) async {
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return [];
    }
    if (categoryId != null) {
      await _ensureCategoryFresh(account, CatalogKind.live, categoryId);
    } else {
      await _ensureSliceBootstrapped(account, CatalogKind.live);
    }
    final query = _db.channelsTable.select()
      ..where((t) => t.accountId.equals(account.id))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    } else if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
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
    bool refresh = true,
  }) async {
    // Content-language filter on the unscoped list with no allowed categories
    // → nothing (skip the query).
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return [];
    }
    if (!refresh) {
      // Cache only. The category-rail screens read this way so that building a
      // screenful of rails can never block on the network — they decide
      // separately, and sparingly, which categories are worth warming.
    } else if (categoryId != null) {
      await _ensureCategoryFresh(account, CatalogKind.vod, categoryId);
    } else {
      await _ensureSliceBootstrapped(account, CatalogKind.vod);
    }
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
    bool refresh = true,
  }) async {
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return [];
    }
    if (!refresh) {
      // Cache only — see the note in [movies].
    } else if (categoryId != null) {
      await _ensureCategoryFresh(account, CatalogKind.series, categoryId);
    } else {
      await _ensureSliceBootstrapped(account, CatalogKind.series);
    }
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
    await _ensureSliceBootstrapped(account, CatalogKind.vod);
    final query = _db.moviesTable.select()
      ..where((t) => t.accountId.equals(account.id))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAtMillisUtc)])
      ..limit(limit);
    if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  // `topRatedMovies` / `topRatedSeries` used to live here, powering Home's
  // "Popular" rails. Removed with those rails: a rating with no vote count
  // behind it ranks a film four people liked above one four million liked,
  // which is the whole reason the discovery rails exist.

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

  /// Fetches and caches any movies or series referenced by [contentKeys] that
  /// are not already in the local cache.
  ///
  /// Continue Watching and My List resolve a saved key against the cached
  /// catalogue and silently drop whatever they cannot find. On a device that
  /// pulled those keys from ANOTHER device — a freshly paired TV — the titles
  /// have usually never been browsed here, so they are absent from the lazily
  /// built cache and every row vanishes even though the sync itself worked.
  /// This pulls the missing titles in once; afterwards they resolve from cache
  /// like anything else.
  ///
  /// Best-effort and bounded: per-title failures are swallowed (a title the
  /// panel has since dropped simply stays unresolved), and fetches run a few at
  /// a time rather than stampeding the panel with a long list.
  ///
  /// Episode keys are intentionally not handled: an episode cannot be fetched
  /// without its series id, which the content key does not carry. Series
  /// Continue Watching therefore needs the separate series-id-in-sync change.
  Future<void> ensureTitlesCached(
    Account account,
    Iterable<String> contentKeys, {
    Iterable<String> extraSeriesIds = const [],
  }) async {
    // Whole-body guard: this is a best-effort enhancement on Home's critical
    // path, so it must never throw back into the caller and turn a working
    // (cached) Home into an error screen. Whatever goes wrong, the rails just
    // fall back to what is already cached.
    try {
      final movieIds = <String>[];
      final seriesIds = <String>{};
      for (final key in contentKeys) {
        final parsed = parseContentKey(key);
        if (parsed == null || parsed.accountId != account.id) continue;
        if (parsed.type == StreamType.movie.name) {
          if (await movieById(account, parsed.id) == null) {
            movieIds.add(parsed.id);
          }
        } else if (parsed.type == seriesContentType) {
          if (await seriesById(account, parsed.id) == null) {
            seriesIds.add(parsed.id);
          }
        }
      }
      // Series behind episode progress: the content key is the episode, which
      // cannot be fetched on its own, so the series id is supplied separately
      // (from what sync pulled). Fetching the series caches all its episodes,
      // which is what lets a series you were part-way through resolve into
      // Continue Watching on a freshly paired device.
      for (final id in extraSeriesIds) {
        if (await seriesById(account, id) == null) seriesIds.add(id);
      }
      if (movieIds.isEmpty && seriesIds.isEmpty) return;

      // Cap the work: only enough to fill what the rails actually show, so a
      // huge synced history can't turn the first Home load into a minutes-long
      // fetch. The rest fill in as they are browsed.
      const maxToFetch = 24;

      Future<void> fetchAll(
          Iterable<String> ids, Future<void> Function(String) fetch) async {
        const maxConcurrent = 4;
        final take = ids.take(maxToFetch).toList();
        for (var i = 0; i < take.length; i += maxConcurrent) {
          await Future.wait(take.skip(i).take(maxConcurrent).map((id) async {
            try {
              await fetch(id).timeout(const Duration(seconds: 12));
            } on Object {
              // A title the panel no longer serves, or a slow one, just stays
              // unresolved rather than holding up the rest.
            }
          }));
        }
      }

      await fetchAll(movieIds, (id) => movieDetail(account, id));
      await fetchAll(seriesIds, (id) => seriesDetail(account, id));
    } on Object catch (e, s) {
      developer.log('ensureTitlesCached failed: $e',
          name: 'CatalogRepository', error: e, stackTrace: s);
    }
  }

  /// Cache-only episode list for one series, in broadcast order. Used to work
  /// out which episode comes after the one you just finished.
  Future<List<Episode>> episodesOfSeries(
      Account account, String seriesId) async {
    final rows = await (_db.episodesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.seriesId.equals(seriesId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.seasonNumber),
            (t) => OrderingTerm.asc(t.episodeNumber),
          ]))
        .get();
    return rows.map((r) => r.toModel()).toList();
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

  /// Channels whose EPG key is in [keys], cache-only, in list order.
  ///
  /// A channel's guide key is `epgChannelId ?? id`, so both columns are matched.
  /// Used by the guide, which starts from the channels that *have* EPG rather
  /// than from the full 25k channel list.
  Future<List<Channel>> channelsByEpgKeys(
      Account account, Set<String> keys) async {
    if (keys.isEmpty) return const [];
    // `epgChannelId IN keys OR id IN keys` binds TWO host variables per key,
    // and SQLite caps host variables per statement. A guide on a large line can
    // start from tens of thousands of EPG keys, which would blow that cap and
    // throw. Query in chunks and merge — 450 keys → 900 variables, safe under
    // any SQLite build's limit.
    const chunkSize = 450;
    final list = keys.toList();
    final byId = <String, ChannelRow>{};
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.skip(i).take(chunkSize).toList();
      final rows = await (_db.channelsTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) &
                (t.epgChannelId.isIn(chunk) | t.id.isIn(chunk))))
          .get();
      for (final r in rows) {
        byId[r.id] = r;
      }
    }
    final rows = byId.values.toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return rows.map((r) => r.toModel()).toList();
  }

  /// Movies whose genre or title matches any of the given keywords.
  ///
  /// Backs the seasonal rails. Cache-only and deliberately unfussy: panel genre
  /// strings are inconsistent ("Horror", "horror/thriller", sometimes empty),
  /// so this matches loosely across both fields and lets the caller rank what
  /// comes back. Ordered by rating so a keyword that catches a lot of rubbish
  /// still surfaces the better end of it.
  Future<List<Movie>> moviesByKeywords(
    Account account, {
    List<String> genreKeywords = const [],
    List<String> titleKeywords = const [],
    Set<String>? categoryIds,
    int limit = 60,
  }) async {
    if (genreKeywords.isEmpty && titleKeywords.isEmpty) return const [];
    if (categoryIds != null && categoryIds.isEmpty) return const [];

    // Category names are the third place the signal hides, and on many lines
    // the only one: `genre` is frequently absent from the panel's list response
    // entirely, so a catalogue that has never had its detail pages opened has
    // no genre at all. A "Horror" or "Kerst" category is just as good a match.
    final seasonCategories = <String>{};
    for (final keyword in [...genreKeywords, ...titleKeywords]) {
      final rows = await (_db.categoriesTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) &
                t.type.equalsValue(CategoryType.vod) &
                t.name.like(_likeTerm(keyword))))
          .get();
      seasonCategories.addAll(rows.map((r) => r.id));
    }

    final query = _db.moviesTable.select()
      ..where((t) => t.accountId.equals(account.id))
      ..orderBy([(t) => OrderingTerm.desc(t.rating)])
      ..limit(limit);
    if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
    query.where((t) {
      Expression<bool>? any;
      void or(Expression<bool> e) => any = any == null ? e : any! | e;
      for (final k in genreKeywords) {
        or(t.genre.like(_likeTerm(k)));
      }
      for (final k in titleKeywords) {
        or(t.name.like(_likeTerm(k)));
      }
      if (seasonCategories.isNotEmpty) {
        or(t.categoryId.isIn(seasonCategories));
      }
      return any!;
    });
    return (await query.get()).map((r) => r.toModel()).toList();
  }

  /// Applies the same channel scoping as [channels] to an arbitrary query.
  void _scopeChannels(
    SimpleSelectStatement<$ChannelsTableTable, ChannelRow> query,
    Account account,
    String? categoryId,
    Set<String>? categoryIds,
  ) {
    query.where((t) => t.accountId.equals(account.id));
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    } else if (categoryIds != null) {
      query.where((t) => t.categoryId.isIn(categoryIds));
    }
  }

  /// The channel at [index] within the same ordering [channels] uses.
  ///
  /// This is what channel up/down zapping rides on. Deliberately a single
  /// indexed row read rather than "hold the channel list in memory and step
  /// through it": on this line that list is 25k entries, and keeping it live
  /// behind the player is exactly the kind of whole-slice residency the
  /// catalogue work removed everywhere else.
  Future<Channel?> channelAt(
    Account account,
    int index, {
    String? categoryId,
    Set<String>? categoryIds,
  }) async {
    if (index < 0) return null;
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return null;
    }
    final query = _db.channelsTable.select()
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ..limit(1, offset: index);
    _scopeChannels(query, account, categoryId, categoryIds);
    return (await query.getSingleOrNull())?.toModel();
  }

  /// How many channels the current scope holds — the wrap-around point for
  /// zapping. Cache-only; a COUNT over an indexed column.
  Future<int> channelCount(
    Account account, {
    String? categoryId,
    Set<String>? categoryIds,
  }) async {
    if (categoryId == null && categoryIds != null && categoryIds.isEmpty) {
      return 0;
    }
    final count = _db.channelsTable.id.count();
    final query = _db.selectOnly(_db.channelsTable)..addColumns([count]);
    query.where(_db.channelsTable.accountId.equals(account.id));
    if (categoryId != null) {
      query.where(_db.channelsTable.categoryId.equals(categoryId));
    } else if (categoryIds != null) {
      query.where(_db.channelsTable.categoryId.isIn(categoryIds));
    }
    return (await query.getSingle()).read(count) ?? 0;
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

  /// Escapes the LIKE metacharacters so a typed `%` or `_` searches for that
  /// character instead of acting as a wildcard — typing `%` used to match the
  /// entire catalogue.
  static String _likeTerm(String query) {
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  Future<List<Movie>> searchMovies(Account account, String query,
      {int limit = 30}) async {
    final term = _likeTerm(query);
    // Cast is searched too: "films with Tom Hanks" is a real way people look,
    // and the column is already populated for anything with a detail fetch.
    final rows = await (_db.moviesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              (t.name.like(term) | t.cast.like(term)))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Series>> searchSeries(Account account, String query,
      {int limit = 30}) async {
    final term = _likeTerm(query);
    final rows = await (_db.seriesTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              (t.name.like(term) | t.cast.like(term)))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Channel>> searchChannels(Account account, String query,
      {int limit = 30}) async {
    final rows = await (_db.channelsTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.name.like(_likeTerm(query)))
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
      await (_db.catalogCategoryMetaTable.delete()
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

