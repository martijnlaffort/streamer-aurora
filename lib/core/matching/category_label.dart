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

final _separators = kNameSeparators;
final _whitespace = RegExp(r'\s+');

/// A readable version of [raw] for headings and titles.
///
/// Splits on the panel's separators, drops segments that are purely language or
/// packaging tags, and title-cases what survives. Returns [raw] trimmed if
/// nothing survives — better a noisy heading than a blank one.
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
  return segments.map(_titleCase).join(' · ');
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
        // Things like "4K" or "2026" keep their shape.
        if (RegExp(r'^\d').hasMatch(word)) return bare;
        final lower = word.toLowerCase();
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
