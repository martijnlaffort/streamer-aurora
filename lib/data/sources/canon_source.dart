import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/models/discovery.dart';
import 'json_values.dart';

/// Loads the bundled award canon (`assets/canon/canon.json`).
///
/// Deliberately offline: award winners do not change more than once a year, and
/// keeping them local means the Award Winners rails work with no API key, no
/// network, and no dependency that can rot. Entries are ordered newest-first,
/// so the rail leads with recent winners rather than 1927.
class CanonSource {
  CanonSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Map<String, List<DiscoveryTitle>>? _cache;

  static const _assetPath = 'assets/canon/canon.json';

  Future<Map<String, List<DiscoveryTitle>>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_assetPath);
    final map = optMap(jsonDecode(raw)) ?? const <String, dynamic>{};
    final result = {
      'movies': _parse(listOr(map['movies'])),
      'series': _parse(listOr(map['series'])),
    };
    return _cache = result;
  }

  List<DiscoveryTitle> _parse(List<dynamic> rows) {
    final entries = <({String title, int? year})>[];
    for (final row in rows) {
      final map = optMap(row);
      if (map == null) continue;
      final title = optString(map['t']);
      if (title == null) continue;
      entries.add((title: title, year: optInt(map['y'])));
    }
    // Newest first: a rail that opens on this year's winner is far more useful
    // than one that opens on Wings (1927).
    entries.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    return [
      for (final (index, e) in entries.indexed)
        DiscoveryTitle(title: e.title, rank: index, year: e.year),
    ];
  }

  Future<List<DiscoveryTitle>> awardWinningMovies() async =>
      (await _load())['movies']!;

  Future<List<DiscoveryTitle>> awardWinningSeries() async =>
      (await _load())['series']!;
}
