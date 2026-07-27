import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show gzip;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/mappers.dart';
import '../sources/playlist_source.dart';
import '../sources/xmltv.dart';

/// EPG access (PRD §8.5): ingests bulk XMLTV (Xtream `xmltv.php` or an M3U
/// account's EPG url) into `epg_cache`, and serves now/next + the guide grid
/// from it. Falls back to per-channel short EPG (Xtream) when no XMLTV exists.
/// All times are UTC in the DB; callers convert to local at the edge.
class EpgRepository {
  EpgRepository({
    required this._db,
    required this._sourceFactory,
    Dio? dio,
    DateTime Function()? clock,
    this.guideTtl = const Duration(hours: 3),
    this.shortEpgTtl = const Duration(minutes: 30),
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              responseType: ResponseType.bytes,
            )),
        _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final PlaylistSource Function(Account) _sourceFactory;
  final Dio _dio;
  final DateTime Function() _clock;
  final Duration guideTtl;
  final Duration shortEpgTtl;

  /// Only keep a window around now — full guides can span weeks.
  static const _pastWindow = Duration(hours: 6);
  static const _futureWindow = Duration(hours: 48);

  /// Guards against overlapping ingests of the same account's guide.
  final Map<String, Future<void>> _inFlight = {};

  String _channelKey(Channel channel) => channel.epgChannelId ?? channel.id;

  // --- Bulk XMLTV ingestion --------------------------------------------------

  /// Fetches + ingests the XMLTV guide when stale (or [force]). No-op when the
  /// account has no XMLTV url. Failures are swallowed — stale/empty EPG is
  /// never fatal.
  Future<void> refreshGuide(Account account, {bool force = false}) async {
    final url = _sourceFactory(account).xmltvUrl;
    if (url == null) return;

    if (!force) {
      final newest = await (_db.epgCacheTable.selectOnly()
            ..addColumns([_db.epgCacheTable.cachedAtMillisUtc.max()])
            ..where(_db.epgCacheTable.accountId.equals(account.id)))
          .getSingleOrNull();
      final cachedAt = newest?.read(_db.epgCacheTable.cachedAtMillisUtc.max());
      if (cachedAt != null &&
          _clock().difference(fromUtcMillis(cachedAt)) <= guideTtl) {
        return;
      }
    }

    // Coalesce concurrent callers onto one fetch.
    final existing = _inFlight[account.id];
    if (existing != null) return existing;
    final future = _ingest(account, url).whenComplete(() {
      _inFlight.remove(account.id);
    });
    _inFlight[account.id] = future;
    return future;
  }

  Future<void> _ingest(Account account, String url) async {
    try {
      final response = await _dio.get<List<int>>(url,
          options: Options(responseType: ResponseType.bytes));
      var bytes = response.data ?? const <int>[];
      // Some panels serve gzipped XMLTV regardless of extension.
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = gzip.decode(bytes);
      }
      final text = String.fromCharCodes(bytes);
      final now = _clock();
      final from = now.subtract(_pastWindow);
      final to = now.add(_futureWindow);
      final nowMillis = utcMillis(now);

      final rows = <EpgCacheTableCompanion>[];
      for (final e in parseXmltv(text,
          onSkip: (m) =>
              developer.log('xmltv: $m', name: 'EpgRepository'))) {
        // Keep only the useful window to bound the table size.
        if (e.stop.isBefore(from) || e.start.isAfter(to)) continue;
        rows.add(EpgCacheTableCompanion.insert(
          accountId: account.id,
          channelId: e.channelId,
          startMillisUtc: utcMillis(e.start),
          stopMillisUtc: utcMillis(e.stop),
          title: e.title,
          description: Value(e.description),
          cachedAtMillisUtc: nowMillis,
        ));
      }
      if (rows.isEmpty) return;

      await _db.transaction(() async {
        await (_db.epgCacheTable.delete()
              ..where((t) => t.accountId.equals(account.id)))
            .go();
        // Insert in chunks — full guides can be tens of thousands of rows.
        const chunk = 500;
        for (var i = 0; i < rows.length; i += chunk) {
          final end = (i + chunk < rows.length) ? i + chunk : rows.length;
          await _db.batch((b) => b.insertAll(
              _db.epgCacheTable, rows.sublist(i, end),
              mode: InsertMode.insertOrReplace));
        }
      });
    } on Object catch (e) {
      developer.log('guide refresh failed: $e', name: 'EpgRepository');
    }
  }

  // --- Reads -----------------------------------------------------------------

  /// Now + the next few programmes for a channel. Prefers the ingested XMLTV
  /// guide; falls back to the source's per-channel short EPG (Xtream) when no
  /// XMLTV exists for the account.
  Future<List<EpgEntry>> nowNext(Account account, Channel channel,
      {int limit = 2}) async {
    final key = _channelKey(channel);
    final source = _sourceFactory(account);

    if (source.xmltvUrl != null) {
      await refreshGuide(account);
      final now = utcMillis(_clock());
      final rows = await (_db.epgCacheTable.select()
            ..where((t) =>
                t.accountId.equals(account.id) &
                t.channelId.equals(key) &
                t.stopMillisUtc.isBiggerThanValue(now))
            ..orderBy([(t) => OrderingTerm.asc(t.startMillisUtc)])
            ..limit(limit))
          .get();
      if (rows.isNotEmpty) return rows.map((r) => r.toModel()).toList();
    }

    return _perChannelShortEpg(account, channel, key, limit);
  }

  /// Legacy per-channel path (Xtream `get_short_epg`) with its own short TTL.
  Future<List<EpgEntry>> _perChannelShortEpg(
      Account account, Channel channel, String key, int limit) async {
    final cached = await (_db.epgCacheTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) & t.channelId.equals(key))
          ..orderBy([(t) => OrderingTerm.asc(t.startMillisUtc)]))
        .get();
    final fresh = cached.isNotEmpty &&
        _clock().difference(fromUtcMillis(cached.first.cachedAtMillisUtc)) <=
            shortEpgTtl;
    if (fresh) return cached.map((r) => r.toModel()).toList();

    try {
      final entries =
          await _sourceFactory(account).getShortEpg(channel.id, limit: limit);
      if (entries.isEmpty) return cached.map((r) => r.toModel()).toList();
      final now = utcMillis(_clock());
      await _db.transaction(() async {
        await (_db.epgCacheTable.delete()
              ..where((t) =>
                  t.accountId.equals(account.id) & t.channelId.equals(key)))
            .go();
        await _db.batch((b) => b.insertAll(_db.epgCacheTable, [
              for (final e in entries)
                EpgCacheTableCompanion.insert(
                  accountId: account.id,
                  channelId: key,
                  startMillisUtc: utcMillis(e.start),
                  stopMillisUtc: utcMillis(e.stop),
                  title: e.title,
                  description: Value(e.description),
                  cachedAtMillisUtc: now,
                ),
            ]));
      });
      return entries;
    } on SourceException {
      return cached.map((r) => r.toModel()).toList();
    }
  }

  /// The programme airing on [channel] at [at] (UTC), if any. Refreshes the
  /// bulk guide first; falls back to whatever a prior now/next cached.
  Future<EpgEntry?> currentProgramme(Account account, Channel channel,
      {DateTime? at}) async {
    await refreshGuide(account);
    final key = _channelKey(channel);
    final t = utcMillis(at ?? _clock());
    final row = await (_db.epgCacheTable.select()
          ..where((tbl) =>
              tbl.accountId.equals(account.id) &
              tbl.channelId.equals(key) &
              tbl.startMillisUtc.isSmallerOrEqualValue(t) &
              tbl.stopMillisUtc.isBiggerThanValue(t))
          ..limit(1))
        .getSingleOrNull();
    return row?.toModel();
  }

  /// Programmes on [channelKey] overlapping [from, to] — for the guide grid.
  Future<List<EpgEntry>> programmes(
      Account account, String channelKey, DateTime from, DateTime to) async {
    final rows = await (_db.epgCacheTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              t.channelId.equals(channelKey) &
              t.stopMillisUtc.isBiggerThanValue(utcMillis(from)) &
              t.startMillisUtc.isSmallerThanValue(utcMillis(to)))
          ..orderBy([(t) => OrderingTerm.asc(t.startMillisUtc)]))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// All programmes overlapping [from, to] for the account, grouped by channel
  /// key — one query for the whole guide grid. Refreshes the guide first.
  Future<Map<String, List<EpgEntry>>> guideWindow(
      Account account, DateTime from, DateTime to) async {
    await refreshGuide(account);
    final rows = await (_db.epgCacheTable.select()
          ..where((t) =>
              t.accountId.equals(account.id) &
              t.stopMillisUtc.isBiggerThanValue(utcMillis(from)) &
              t.startMillisUtc.isSmallerThanValue(utcMillis(to)))
          ..orderBy([(t) => OrderingTerm.asc(t.startMillisUtc)]))
        .get();
    final grouped = <String, List<EpgEntry>>{};
    for (final row in rows) {
      (grouped[row.channelId] ??= []).add(row.toModel());
    }
    return grouped;
  }

  /// Whether any EPG is cached for this account (drives guide empty-states).
  Future<bool> hasEpg(Account account) async {
    final row = await (_db.epgCacheTable.select()
          ..where((t) => t.accountId.equals(account.id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }
}
