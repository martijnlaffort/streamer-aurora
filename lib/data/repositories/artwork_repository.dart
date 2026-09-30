import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/matching/title_match.dart';
import '../db/app_database.dart';
import '../sources/tmdb_source.dart';

/// Cache key for a title's artwork: the same normalisation used for matching,
/// plus the year when we have one. Two spellings of the same film share a
/// lookup; two different films with the same name do not.
String artworkKeyFor(String name, int? year) {
  final normalized = normalizeTitle(name, knownYear: year);
  return year != null ? '$normalized@$year' : normalized;
}

/// Artwork for titles the panel supplies no image for.
///
/// Some entries on a playlist simply have no poster — the reported "series that
/// is nothing" was the Emmy winner ER, matched correctly and captioned
/// correctly, with no artwork on the line. This fills those gaps from TMDB.
///
/// Three properties keep it from becoming a request storm across a 150k-title
/// catalogue:
///
///  * it is only ever consulted for a card that has *no* poster already, so it
///    runs over a small tail rather than the catalogue;
///  * lookups are demand-driven from visible cards, so nothing is fetched for
///    titles never scrolled past;
///  * an empty result is cached as [ArtworkRow.missing], so a title TMDB does
///    not know is asked about once rather than on every scroll.
class ArtworkRepository {
  ArtworkRepository(this._db, this._tmdb);

  final AppDatabase _db;

  /// Rebuilt per read so a key added in Settings takes effect without a
  /// restart, and so no TMDB client exists at all when no key is configured.
  final TmdbSource? Function() _tmdb;

  /// In-flight lookups, so a rail that shows the same title twice — or a
  /// rebuild mid-request — makes one call rather than several.
  final Map<String, Future<String?>> _inFlight = {};

  /// A modest ceiling on concurrent TMDB calls. The API tolerates far more, but
  /// it is rate-limited *by IP*, and racing dozens of requests off one scroll
  /// risks a 429 that would affect the discovery rails too.
  ///
  /// Lookups over the ceiling WAIT for a slot. They used to return "no
  /// artwork" instead, and the card kept that answer for five minutes — so on
  /// a rail with several posterless titles, everything past the fourth stayed
  /// a grey tile even with a key configured.
  static const _maxConcurrent = 4;
  int _active = 0;
  final List<Completer<void>> _waiting = [];

  Future<void> _acquire() async {
    while (_active >= _maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _active++;
  }

  void _release() {
    _active--;
    if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
  }

  /// Cached poster for [name], or null if we do not have one.
  ///
  /// [fetch] false reads cache only — used where a miss should not trigger
  /// network work.
  Future<String?> posterFor({
    required String name,
    int? year,
    required bool isSeries,
    bool fetch = true,
  }) async {
    final kind = isSeries ? 'series' : 'movie';
    final key = artworkKeyFor(name, year);
    final cached = await _read(kind, key);
    if (cached != null) return cached.missing ? null : cached.posterUrl;
    if (!fetch) return null;

    final dedupeKey = '$kind/$key';
    final existing = _inFlight[dedupeKey];
    if (existing != null) return existing;

    final future = _fetch(kind: kind, key: key, name: name, year: year,
        isSeries: isSeries);
    _inFlight[dedupeKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(dedupeKey);
    }
  }

  Future<ArtworkRow?> _read(String kind, String key) =>
      (_db.artworkCacheTable.select()
            ..where((t) => t.kind.equals(kind) & t.titleKey.equals(key)))
          .getSingleOrNull();

  Future<String?> _fetch({
    required String kind,
    required String key,
    required String name,
    required int? year,
    required bool isSeries,
  }) async {
    final tmdb = _tmdb();
    if (tmdb == null) return null; // No key configured — nothing to ask.
    await _acquire();
    try {
      final found =
          await tmdb.findArtwork(title: name, year: year, isTv: isSeries);
      if (found == null) return null;
      await _db.artworkCacheTable.insertOnConflictUpdate(
        ArtworkCacheTableCompanion.insert(
          kind: kind,
          titleKey: key,
          posterUrl: Value(found.posterUrl),
          backdropUrl: Value(found.backdropUrl),
          missing: Value(found.posterUrl == null && found.backdropUrl == null),
          fetchedAtMillisUtc: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
      return found.posterUrl;
    } on Exception {
      // Network trouble is not evidence that the title has no artwork, so
      // nothing is written and the next attempt is free to retry.
      return null;
    } finally {
      _release();
    }
  }
}
