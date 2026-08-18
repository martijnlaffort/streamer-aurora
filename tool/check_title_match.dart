// Dev utility for tuning the discovery title matcher against real playlist
// names — the one part of the discovery feature that can silently under-deliver.
//
// ignore_for_file: avoid_print — this is a command-line tool; stdout IS its UI.
//
// Run:  dart run tool/check_title_match.dart
// Or:   dart run tool/check_title_match.dart "EN - Oppenheimer 2023 4K"
//
// With no arguments it runs the built-in cases below: each line is a panel-style
// name paired with the clean title it must match. Anything marked MISS means the
// rail would silently skip that title, which is the failure mode to watch for.
import 'package:dawnplayer/core/matching/title_match.dart';

/// (messy panel name, panel year or null, clean external title, external year)
const _cases = <(String, int?, String, int?)>[
  // Straightforward.
  ('Oppenheimer', 2023, 'Oppenheimer', 2023),
  ('Oppenheimer (2023)', null, 'Oppenheimer', 2023),
  // Quality / codec / language noise.
  ('Oppenheimer 2023 4K MULTi', null, 'Oppenheimer', 2023),
  ('EN - Oppenheimer 1080p x265', 2023, 'Oppenheimer', 2023),
  ('NL| Oppenheimer IMAX Extended', 2023, 'Oppenheimer', 2023),
  ('VOD Oppenheimer WEB-DL HDR10 Atmos', 2023, 'Oppenheimer', 2023),
  // Punctuation, articles, diacritics.
  ('The Godfather Part II', 1974, 'The Godfather Part II', 1974),
  ('Godfather Part 2', 1974, 'The Godfather Part II', 1974),
  ('Amelie', 2001, 'Amélie', 2001),
  ('Shogun', 2024, 'Shōgun', 2024),
  // Panels routinely drop apostrophes.
  ('Schindlers List 1993', 1993, "Schindler's List", 1993),
  ('WALL-E', 2008, 'WALL·E', 2008),
  ("One Flew Over the Cuckoo's Nest", 1975, "One Flew Over the Cuckoo's Nest", 1975),
  ('M*A*S*H', null, 'M*A*S*H', 1974),
  // Year drift between panel and TMDB (festival vs general release).
  ('Parasite', 2020, 'Parasite', 2019),
  // Titles that legitimately contain a year — must NOT lose it.
  ('2001: A Space Odyssey', 1968, '2001: A Space Odyssey', 1968),
  ('Blade Runner 2049', 2017, 'Blade Runner 2049', 2017),
  // Should NOT match: different films that normalize close but not equal.
  ('Dune Part Two', 2024, 'Dune', 2021),
  ('The Batman', 2022, 'Batman', 1989),
];

void main(List<String> args) {
  if (args.isNotEmpty) {
    for (final raw in args) {
      final key = titleKeyFor(raw);
      print('$raw\n  -> normalized: "${key.normalized}"  year: ${key.year}');
    }
    return;
  }

  var hits = 0, misses = 0, unexpected = 0;
  for (final (panelName, panelYear, cleanTitle, cleanYear) in _cases) {
    final a = titleKeyFor(panelName, year: panelYear);
    final b = titleKeyFor(cleanTitle, year: cleanYear);
    final matched = a.matches(b);
    // The last two cases are deliberate non-matches.
    final shouldMatch = !(panelName == 'Dune Part Two' || panelName == 'The Batman');
    final ok = matched == shouldMatch;
    if (!ok) {
      if (shouldMatch) {
        misses++;
      } else {
        unexpected++;
      }
    } else if (shouldMatch) {
      hits++;
    }
    final verdict = ok ? (shouldMatch ? 'HIT ' : 'SKIP') : 'FAIL';
    print('$verdict  ${panelName.padRight(40)} '
        '"${a.normalized}" ${matched ? '==' : '!='} "${b.normalized}"');
  }
  print('\n$hits matched as intended, $misses missed, '
      '$unexpected false positives');
}
