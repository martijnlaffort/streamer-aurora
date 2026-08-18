// Shows what the Wikipedia trending source would feed the discovery rails.
//
//   dart run tool/check_wikipedia_trending.dart
//   dart run tool/check_wikipedia_trending.dart nl.wikipedia en.wikipedia
//
// Useful because the rail is only as good as this filtering: the raw chart is
// dominated by meta pages and news articles, and what survives here is what
// gets matched against the catalogue.
//
// ignore_for_file: avoid_print — command-line tool; stdout IS its UI.
import 'package:aurora/data/sources/wikipedia_trending_source.dart';

Future<void> main(List<String> args) async {
  final projects = args.isEmpty ? const ['en.wikipedia'] : args;
  final source = WikipediaTrendingSource(projects: projects);
  print('projects: ${projects.join(', ')}\n');

  for (final series in [false, true]) {
    final titles = await source.trending(series: series);
    print('${series ? 'SERIES' : 'MOVIES'}: ${titles.length} candidates');
    for (final t in titles.take(15)) {
      print('  ${t.rank.toString().padLeft(3)}  ${t.title}');
    }
    print('');
  }
}
