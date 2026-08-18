// Dev utility for tuning display-title cleanup against real provider names.
//
// Run:  dart run tool/check_title_label.dart
// Or:   dart run tool/check_title_label.dart "| NL | Cobra 4K (1986)"
//
// ignore_for_file: avoid_print — command-line tool; stdout IS its UI.
import 'package:dawnplayer/core/matching/title_label.dart';

/// (raw name, panel year, expected display title). The raw names are real ones
/// read off the user's line.
const _cases = <(String, int?, String)>[
  ('| NL | Cobra 4K (1986)', 1986, 'Cobra'),
  ('| NL | The Death of Robin Hood 4K 2026', 2026, 'The Death of Robin Hood'),
  ('| MULTI | 72 HOURS  4K - 2023', 2023, '72 HOURS'),
  ('| MULTI | Masters of the Universe - 2026', 2026, 'Masters of the Universe'),
  ('| MULTI | Scary Movie 4K - 2026', 2026, 'Scary Movie'),
  ('The Devil Wears Prada 2 - 2026', 2026, 'The Devil Wears Prada 2'),
  ('| MULTI | Hacksaw Ridge - 2016', 2016, 'Hacksaw Ridge'),
  ('| NL | Schitt\'s Creek', null, 'Schitt\'s Creek'),
  ('| AR | Schitt\'s Creek', null, 'Schitt\'s Creek'),
  // A number that is part of the name, not a year.
  ('Blade Runner 2049', 2017, 'Blade Runner 2049'),
  ('2001: A Space Odyssey', 1968, '2001: A Space Odyssey'),
  // Stacked release tags.
  ('EN - Oppenheimer 2023 1080p WEB-DL x265', 2023, 'Oppenheimer'),
  // Nothing to strip.
  ('Casablanca', 1943, 'Casablanca'),
  // Pathological: only noise. Anything readable beats a blank caption.
  ('| MULTI |', null, 'MULTI'),
  // Leading tag must NOT be stripped without a separator after it.
  ('In Bruges', 2008, 'In Bruges'),
  ('No Country for Old Men', 2007, 'No Country for Old Men'),
];

void main(List<String> args) {
  if (args.isNotEmpty) {
    for (final raw in args) {
      print('$raw\n  -> "${prettyTitle(raw)}"');
    }
    return;
  }
  var pass = 0, fail = 0;
  for (final (raw, year, expected) in _cases) {
    final got = prettyTitle(raw, year: year);
    final ok = got == expected;
    ok ? pass++ : fail++;
    print('${ok ? 'OK  ' : 'FAIL'}  ${raw.padRight(42)} -> "$got"'
        '${ok ? '' : '   (expected "$expected")'}');
  }
  print('\n$pass passed, $fail failed');
}
