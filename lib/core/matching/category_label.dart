/// Turning a provider's category name into something a person can read.
///
/// Panels name categories for their own bookkeeping, not for a viewer:
/// `| MULTI / LINGO |  4K HDR |`, `| NL | ACTIE`, `| MULTI / LINGO | NEW
/// RELEASES`. Rendered raw as a rail heading these are mostly punctuation and
/// language tags, and the part that carries meaning is pushed off the end of
/// the line by the noise in front of it.
library;

import 'name_tags.dart';

/// Language and packaging tags. A `|`-delimited segment is dropped only when
/// *every* token in it is one of these — so `MULTI / LINGO` goes and `4K HDR`
/// stays, because the latter is the only thing distinguishing that category.
const _segmentNoise = {
  'multi', 'lingo', 'multilingo', 'multisub', 'multisubs', 'dual', 'vip',
  'ex', 'exyu', 'yu', 'all', 'general', 'other', 'various', 'mix', 'mixed',
  // A segment that only says "this is on-demand" says nothing on a Films or
  // Series page.
  'vod',
  // ISO-ish language and country tags panels prefix with.
  'nl', 'ned', 'dut', 'en', 'eng', 'uk', 'us', 'usa', 'fr', 'fra', 'fre',
  'de', 'ger', 'deu', 'es', 'esp', 'spa', 'it', 'ita', 'pt', 'por', 'br',
  'tr', 'tur', 'ar', 'ara', 'ru', 'rus', 'pl', 'pol', 'ro', 'ron', 'rom',
  'se', 'swe', 'no', 'nor', 'dk', 'dan', 'fi', 'fin', 'gr', 'ell', 'gre',
  'hu', 'hun', 'cz', 'ces', 'cze', 'sk', 'al', 'alb', 'in', 'hin', 'ind',
  'lat', 'latino', 'afr', 'bg', 'hr', 'sr', 'si', 'mk', 'ua', 'ukr',
};

/// Tokens to keep upper-case rather than title-case.
const _acronyms = {
  '4K', '8K', 'HD', 'FHD', 'UHD', 'SD', 'HDR', 'HDR10', 'DV', 'TV', 'VOD',
  '3D', 'IMAX', 'UFC', 'NBA', 'NFL', 'MMA', 'WWE', 'BBC', 'HBO', 'DC',
};

/// Country/language tags that stay upper-case when they survive inside a
/// segment ("Prime Video NL", not "Prime Video Nl"). Two-letter tags that are
/// also English words (in, no, it, se, si, al) are left to title case.
const _upperTags = {
  'nl', 'en', 'eng', 'uk', 'us', 'usa', 'fr', 'de', 'es', 'pt', 'br', 'tr',
  'ar', 'ru', 'pl', 'ro', 'dk', 'fi', 'gr', 'hu', 'cz', 'sk', 'bg', 'hr',
  'sr', 'mk', 'ua', 'ex', 'yu', 'exyu',
};

/// Streaming services spelled the way they spell themselves. Panels write
/// `HBOMAX`, `APPLE+`, `AMAZON PRIME`, `DISNEY PLUS`; title case alone turns
/// those into "Hbomax" and "Apple+", which read as typos of something the
/// viewer knows perfectly well. Applied after title-casing, case-blind.
final _brandSpellings = <(RegExp, String)>[
  (_word(r'hbo\s*max'), 'HBO Max'),
  (_word(r'apple\s*(?:tv\s*)?(?:\+|plus)|apple\s*tv'), 'Apple TV+'),
  (_word(r'disney\s*(?:\+|plus)'), 'Disney+'),
  (_word(r'amazon\s*prime(?:\s*video)?|prime\s*video|amazon\s*video'),
      'Prime Video'),
  (_word(r'paramount\s*(?:\+|plus)'), 'Paramount+'),
  (_word(r'discovery\s*(?:\+|plus)'), 'Discovery+'),
  (_word(r'sky\s*showtime'), 'SkyShowtime'),
  (_word(r'npo\s*start'), 'NPO Start'),
  (_word(r'npo'), 'NPO'),
];

RegExp _word(String pattern) =>
    RegExp('(?<![a-z0-9])(?:$pattern)(?![a-z0-9+])', caseSensitive: false);

/// Resolution tags, best first. A segment that stacks several ("4K UHD HD")
/// keeps only the best — the rest is the panel labelling the same thing twice.
const _resolutionRank = {'8K': 4, '4K': 3, 'UHD': 3, 'FHD': 2, 'HD': 1, 'SD': 0};

final _separators = kNameSeparators;
final _whitespace = RegExp(r'\s+');

/// A readable version of [raw] for headings and titles.
///
/// Splits on the panel's separators, drops segments that are purely language or
/// packaging tags, title-cases what survives, spells services the way they
/// spell themselves, and drops repeats. Returns [raw] trimmed if nothing
/// survives — better a noisy heading than a blank one.
String prettyCategoryName(String raw) {
  // Take the bracketed tag off first, so a provider using a bar we do not
  // recognise still loses its `| MULTI / LINGO |` prefix.
  final segments = stripLeadingTag(raw, _isAllNoise)
      .split(_separators)
      .map((s) => s.replaceAll(_whitespace, ' ').trim())
      .where((s) => s.isNotEmpty)
      .where((s) => !_isAllNoise(s))
      .toList();
  if (segments.isEmpty) return raw.replaceAll(_separators, ' ').trim();
  final seen = <String>{};
  final out = <String>[];
  for (final segment in segments) {
    final pretty = _brandSpelled(_bestResolutionOnly(_titleCase(segment)));
    if (pretty.isEmpty || !seen.add(pretty.toLowerCase())) continue;
    out.add(pretty);
  }
  return out.isEmpty ? raw.trim() : out.join(' · ');
}

String _brandSpelled(String segment) {
  var s = segment;
  for (final (pattern, name) in _brandSpellings) {
    s = s.replaceAll(pattern, name);
  }
  return s;
}

String _bestResolutionOnly(String segment) {
  final words = segment.split(' ');
  final ranks = [for (final w in words) _resolutionRank[w]];
  if (ranks.whereType<int>().length < 2) return segment;
  final best = ranks.whereType<int>().reduce((a, b) => a > b ? a : b);
  final kept = <String>[];
  var bestKept = false;
  for (var i = 0; i < words.length; i++) {
    final rank = ranks[i];
    if (rank == null) {
      kept.add(words[i]);
    } else if (rank == best && !bestKept) {
      kept.add(words[i]);
      bestKept = true;
    }
  }
  return kept.join(' ');
}

/// True when every word in the segment is a language/packaging tag.
bool _isAllNoise(String segment) {
  final words = segment
      .split(RegExp(r'[\s/,\-]+'))
      .map((w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  return words.every(_segmentNoise.contains);
}

String _titleCase(String segment) {
  return segment
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((word) {
        final bare = word.toUpperCase();
        if (_acronyms.contains(bare)) return bare;
        if (_upperTags.contains(word.toLowerCase())) return bare;
        // Things like "4K" or "2026" keep their shape.
        if (RegExp(r'^\d').hasMatch(word)) return bare;
        final lower = word.toLowerCase();
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
