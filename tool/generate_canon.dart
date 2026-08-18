// Regenerates assets/canon/canon.json from Wikidata.
//
//   dart run tool/generate_canon.dart            # writes the asset
//   dart run tool/generate_canon.dart --dry-run  # report only
//
// Why Wikidata rather than a metadata API: the canon is the app's escape from
// paid metadata. Award winners and critical canons are FACTS, they change at
// most once a year, and Wikidata publishes them as CC0 — no key, no rate limit,
// no licence fee, and nothing that can be revoked. Running this at build time
// rather than at runtime means the shipped app makes no external call at all.
//
// Each award is fetched with its own English label so a wrong QID is obvious:
// it either reports a name that is not what you expected, or returns nothing.
//
// ignore_for_file: avoid_print — command-line tool; stdout IS its UI.
import 'dart:convert';
import 'dart:io';

/// One source list. Awards are identified by NAME, not by QID.
///
/// Hardcoding QIDs was the first attempt and it was wrong seven times out of
/// twelve — and worse, one wrong id silently returned 29 real-looking rows from
/// an entirely different award. Resolving by label means the script reports
/// what it actually matched, so a mistake is visible rather than baked into the
/// asset.
typedef Award = ({String name, String slug, bool series});

/// Awards given TO A WORK. This matters more than it looks: most acting and
/// directing awards are received by a *person*, so querying them returns
/// people rather than films. The type constraint in the winners query filters
/// those out, and such an award simply reports zero.
const _awards = <Award>[
  // --- Film -----------------------------------------------------------------
  (name: 'Academy Award for Best Picture', slug: 'oscar-bp', series: false),
  (name: 'Palme d\'Or', slug: 'palme-dor', series: false),
  (name: 'Golden Lion', slug: 'golden-lion', series: false),
  (name: 'Golden Bear', slug: 'golden-bear', series: false),
  (name: 'BAFTA Award for Best Film', slug: 'bafta-best-film', series: false),
  (
    name: 'Academy Award for Best International Feature Film',
    slug: 'oscar-intl',
    series: false
  ),
  (
    name: 'Academy Award for Best Animated Feature',
    slug: 'oscar-animated',
    series: false
  ),

  // --- Television -----------------------------------------------------------
  (
    name: 'Primetime Emmy Award for Outstanding Drama Series',
    slug: 'emmy-drama',
    series: true
  ),
  (
    name: 'Primetime Emmy Award for Outstanding Comedy Series',
    slug: 'emmy-comedy',
    series: true
  ),
  // Renamed repeatedly over the years; the fuzzy fallback finds it whichever
  // name Wikidata currently carries.
  (
    name: 'Primetime Emmy Award for Outstanding Limited',
    slug: 'emmy-limited',
    series: true
  ),
  (
    name: 'Golden Globe Award for Best Television Series',
    slug: 'globe-tv',
    series: true
  ),
];

const _endpoint = 'https://query.wikidata.org/sparql';

/// Wikidata blocks generic agents outright, and asks that tools identify
/// themselves with a contact.
const _userAgent =
    'DawnPlayerCanonGenerator/1.0 (https://github.com/martijnlaffort/streamer-aurora)';

/// Finds the award by exact English label, falling back to a substring match.
///
/// The fallback exists because Wikidata's naming drifts — "Outstanding Limited
/// or Anthology Series" has been renamed more than once — and an exact-label
/// lookup fails silently the moment it does.
String _resolveQuery(Award award, {required bool fuzzy}) {
  final escaped = award.name.replaceAll('"', '\\"');
  final match = fuzzy
      ? '?award rdfs:label ?l . FILTER(LANG(?l) = "en") '
          'FILTER(CONTAINS(LCASE(?l), "${escaped.toLowerCase()}"))'
      : '?award rdfs:label "$escaped"@en .';
  return '''
SELECT ?award WHERE {
  $match
  ?award wdt:P31/wdt:P279* wd:Q618779 .
}
LIMIT 8
''';
}

/// Films: instance of (a subclass of) film. Series: television series.
/// Without this, person-awards return the recipients rather than the work.
String _winnersQuery(Award award, String qid) {
  final type = award.series ? 'wd:Q5398426' : 'wd:Q11424';
  // Both directions. Wikidata records a win either on the work ("award
  // received") or on the award ("winner"), and which one is used varies by
  // award — the television categories are largely the second form, which is
  // why querying only P166 returned 11 Emmy winners instead of seventy.
  return '''
SELECT DISTINCT ?item ?itemLabel ?released ?started WHERE {
  { ?item wdt:P166 wd:$qid . }
  UNION
  { wd:$qid wdt:P1346 ?item . }
  ?item wdt:P31/wdt:P279* $type .
  OPTIONAL { ?item wdt:P577 ?released }
  OPTIONAL { ?item wdt:P580 ?started }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" }
}
''';
}

/// Runs a query, retrying the failures a free shared endpoint actually
/// produces: 429 when it decides you are going too fast, and 502/503 when the
/// query service is briefly overloaded. Both were hit on the first run.
Future<List<Map<String, dynamic>>> _run(String sparql) async {
  const retryable = {429, 500, 502, 503, 504};
  var attempt = 0;
  while (true) {
    attempt++;
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final uri = Uri.parse(
          '$_endpoint?format=json&query=${Uri.encodeQueryComponent(sparql)}');
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/sparql-results+json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (retryable.contains(response.statusCode) && attempt < 4) {
        stdout.write('[${response.statusCode}, retry $attempt] ');
        await Future<void>.delayed(Duration(seconds: 5 * attempt));
        continue;
      }
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: '
            '${body.substring(0, body.length.clamp(0, 160))}');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final bindings =
          (decoded['results'] as Map<String, dynamic>)['bindings'] as List;
      return bindings.cast<Map<String, dynamic>>();
    } on Object catch (e) {
      // A dropped connection mid-response is as routine here as a 502, and was
      // hit on the first run. Retry it the same way rather than losing an
      // entire award to a transport hiccup.
      if (e is HttpException && '$e'.contains('HTTP ')) rethrow;
      if (attempt >= 4) rethrow;
      stdout.write('[${e.runtimeType}, retry $attempt] ');
      await Future<void>.delayed(Duration(seconds: 5 * attempt));
    } finally {
      client.close(force: true);
    }
  }
}

String? _value(Map<String, dynamic> row, String key) =>
    (row[key] as Map<String, dynamic>?)?['value'] as String?;

int? _year(Map<String, dynamic> row) {
  for (final key in ['released', 'started']) {
    final raw = _value(row, key);
    if (raw != null && raw.length >= 4) {
      final y = int.tryParse(raw.substring(0, 4));
      if (y != null && y > 1880 && y < 2100) return y;
    }
  }
  return null;
}

/// Matches the app's own title normalisation closely enough to dedupe on.
String _key(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The hand-verified list this generator grew out of, sourced from Wikipedia's
/// complete award tables.
///
/// It is merged in rather than replaced because Wikidata's coverage is uneven:
/// excellent for film awards, thin for television. Querying "Outstanding Drama
/// Series" returns about a dozen series — the relation simply is not recorded
/// on most of them — where Wikipedia's table has seventy. Dropping the seed to
/// look purely generated would have quietly lost most of the TV canon.
const _seedPath = 'tool/canon_seed.json';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');

  // Keyed by normalised title so a film that won at Cannes AND the Oscars
  // appears once, tagged with the first award that found it.
  final movies = <String, ({String t, int? y, String s})>{};
  final series = <String, ({String t, int? y, String s})>{};
  var failures = 0;

  final seedFile = File(_seedPath);
  if (seedFile.existsSync()) {
    final seed = jsonDecode(await seedFile.readAsString()) as Map<String, dynamic>;
    for (final (key, target) in [('movies', movies), ('series', series)]) {
      for (final row in (seed[key] as List? ?? const [])) {
        final map = (row as Map).cast<String, dynamic>();
        final title = map['t'] as String?;
        if (title == null) continue;
        target[_key(title)] = (
          t: title,
          y: map['y'] as int?,
          s: map['s'] as String? ?? 'seed',
        );
      }
    }
    print('  seed               '
        '${movies.length} movies, ${series.length} series (curated)\n');
  }

  for (final award in _awards) {
    stdout.write('  ${award.slug.padRight(18)} ');
    try {
      var resolved = await _run(_resolveQuery(award, fuzzy: false));
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (resolved.isEmpty) {
        resolved = await _run(_resolveQuery(award, fuzzy: true));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      if (resolved.isEmpty) {
        failures++;
        print('NOT FOUND — nothing matching "${award.name}"');
        continue;
      }

      // A label like "Golden Lion" is ambiguous and the first candidate can be
      // the wrong entity — which shows up as zero winners, not as an error.
      // Walk the candidates until one actually has winners.
      var qid = '';
      var rows = <Map<String, dynamic>>[];
      for (final candidate in resolved) {
        qid = _value(candidate, 'award')!.split('/').last;
        rows = await _run(_winnersQuery(award, qid));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (rows.isNotEmpty) break;
      }
      final target = award.series ? series : movies;
      final before = target.length;
      var skipped = 0;

      for (final row in rows) {
        final label = _value(row, 'itemLabel');
        // An unlabelled item comes back as its QID; those are entries with no
        // English label and are useless for title matching.
        if (label == null || RegExp(r'^Q\d+$').hasMatch(label)) {
          skipped++;
          continue;
        }
        final key = _key(label);
        if (key.isEmpty) continue;
        final year = _year(row);
        final existing = target[key];
        // Keep the earliest year: for a series this is the first win, which is
        // what the existing asset records.
        if (existing == null ||
            (year != null && (existing.y == null || year < existing.y!))) {
          target[key] = (t: label, y: year ?? existing?.y, s: award.slug);
        }
      }

      final added = target.length - before;
      print('$qid  ${rows.length.toString().padLeft(4)} winners  '
          '+$added new${skipped > 0 ? '  ($skipped unlabelled)' : ''}');
      if (rows.isEmpty) failures++;
    } on Object catch (e) {
      failures++;
      print('FAILED: $e');
    }
    // Be a good citizen of a free, donation-funded endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }

  print('\nmovies: ${movies.length}   series: ${series.length}');
  if (failures > 0) {
    print('$failures award(s) returned nothing — fix or remove those QIDs.');
  }
  if (movies.isEmpty || series.isEmpty) {
    print('Refusing to write: one of the lists is empty.');
    exit(1);
  }

  List<Map<String, dynamic>> encode(
          Map<String, ({String t, int? y, String s})> m) =>
      (m.values.toList()
            ..sort((a, b) => (b.y ?? 0).compareTo(a.y ?? 0)))
          .map((e) => {'t': e.t, if (e.y != null) 'y': e.y, 's': e.s})
          .toList();

  final asset = {
    'version': 2,
    'note': 'Award-winning and canonical titles, bundled so the discovery '
        'rails work with no network, no API key and no metadata licence. '
        'Generated by tool/generate_canon.dart — do not edit by hand, '
        'regenerate. Sources: Wikidata (CC0) for the award tables, merged over '
        'tool/canon_seed.json, a hand-verified list from Wikipedia (CC BY-SA) '
        'that covers the television awards Wikidata records only patchily. '
        '`y` is the release year, or for series the year of its first win; it '
        'only disambiguates remakes, with a tolerance, so it need not be exact.',
    'movies': encode(movies),
    'series': encode(series),
  };

  const encoder = JsonEncoder.withIndent('  ');
  final json = encoder.convert(asset);
  if (dryRun) {
    print('\n--dry-run: not written (${json.length ~/ 1024} KB)');
    return;
  }
  final file = File('assets/canon/canon.json');
  await file.writeAsString('$json\n');
  print('\nwrote ${file.path} (${json.length ~/ 1024} KB)');
}
