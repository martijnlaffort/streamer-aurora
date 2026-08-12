// Dev utility for tuning category-name cleanup against real provider names.
//
// Run:  dart run tool/check_category_label.dart
// Or:   dart run tool/check_category_label.dart "| MULTI / LINGO | 4K HDR |"
//
// ignore_for_file: avoid_print — command-line tool; stdout IS its UI.
import 'package:aurora/core/matching/category_label.dart';

/// Real category names seen on the user's line, plus shapes other panels use.
const _samples = <String>[
  '| MULTI / LINGO |  4K HDR |',
  '| MULTI / LINGO |  NEW RELEASES',
  '| MULTI / LINGO | 4K HDR | ACTION',
  '| NL | ACTIE',
  '| EN | ACTION & ADVENTURE',
  '|MULTI| KIDS',
  'MULTI / LINGO',
  '| AR | DOCUMENTARY',
  'Netflix Originals',
  '| MULTI | 4K UHD |',
  '| EX-YU | FILMOVI',
  '',
];

void main(List<String> args) {
  final inputs = args.isNotEmpty ? args : _samples;
  for (final raw in inputs) {
    print('${raw.padRight(38)} ->  "${prettyCategoryName(raw)}"');
  }
}
