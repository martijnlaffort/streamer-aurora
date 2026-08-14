/// Turning a provider's stream name into a title a person wants to read.
///
/// Panels name streams for their own catalogue, not for a viewer:
/// `| NL | Cobra 4K (1986)`, `| MULTI | Masters of the Universe - 2026`.
/// Rendered raw in a poster caption — which gets two lines — the noise eats
/// both and the actual title is what gets truncated away.
///
/// This is the DISPLAY counterpart to `normalizeTitle` in title_match.dart.
/// That one destroys case and punctuation because it only has to make two
/// strings comparable; this one has to leave something readable, so it removes
/// noise and otherwise keeps the name exactly as the provider wrote it.
///
/// Only ever use this for rendering. Matching, search and content keys must
/// keep working from the raw name.
library;

/// Language and packaging tags panels bracket names with.
const _prefixNoise = {
  'multi', 'multisub', 'multisubs', 'lingo', 'dual', 'vip', 'ex', 'exyu', 'yu',
  'nl', 'ned', 'dut', 'en', 'eng', 'uk', 'us', 'usa', 'fr', 'fra', 'fre',
  'de', 'ger', 'deu', 'es', 'esp', 'spa', 'it', 'ita', 'pt', 'por', 'br',
  'tr', 'tur', 'ar', 'ara', 'ru', 'rus', 'pl', 'pol', 'ro', 'ron', 'rom',
  'se', 'swe', 'no', 'nor', 'dk', 'dan', 'fi', 'fin', 'gr', 'ell', 'gre',
  'hu', 'hun', 'cz', 'ces', 'cze', 'sk', 'al', 'alb', 'in', 'hin', 'ind',
  'lat', 'latino', 'afr', 'bg', 'hr', 'sr', 'si', 'mk', 'ua', 'ukr', 'vod',
};

/// Release/quality tokens, stripped only from the END of a name. Mid-title they
/// can be real words — a film called `Heat` or `Drive` must survive, and
/// `4K` only means "quality tag" when it is trailing junk.
const _trailingNoise = {
  '4k', '8k', 'uhd', 'hd', 'fhd', 'sd', 'hq', 'hdr', 'hdr10', 'dv', 'sdr',
  '1080p', '1080i', '720p', '480p', '2160p', '10bit', '8bit',
  'bluray', 'blueray', 'brrip', 'bdrip', 'webrip', 'web', 'webdl', 'dl',
  'hdrip', 'dvdrip', 'dvd', 'cam', 'hdcam', 'ts', 'telesync', 'proper',
  'repack', 'remux', 'imax', 'multi', 'multisub', 'multisubs', 'dubbed',
  'subbed', 'sub', 'subs', 'vostfr', 'truefrench', 'x264', 'x265', 'h264',
  'h265', 'hevc', 'avc', 'aac', 'ac3', 'dts', 'ddp', 'ddp5', 'truehd',
  'atmos', 'xvid', 'divx', 'amzn', 'nf', 'dsnp', 'hmax', 'atvp',
};

final _separators = RegExp(r'[|•·]+');
final _whitespace = RegExp(r'\s+');
final _plausibleYear = RegExp(r'^(19|20)\d{2}$');

/// A readable title for [raw].
///
/// [year] is the panel's own year column when it has one, and decides the one
/// genuinely ambiguous case: a trailing four-digit number. It is dropped when
/// it corroborates the year we already hold (`Cobra 4K (1986)` → `Cobra`), and
/// KEPT when it disagrees — which is what stops `Blade Runner 2049` from being
/// filed as `Blade Runner`.
String prettyTitle(String raw, {int? year}) {
  // Drop `| NL |`-style segments, keeping the longest remaining piece — the
  // title is essentially always the substantial one.
  final segments = raw
      .split(_separators)
      .map((s) => s.replaceAll(_whitespace, ' ').trim())
      .where((s) => s.isNotEmpty)
      .where((s) => !_isNoiseSegment(s))
      .toList();
  var text = segments.isEmpty
      ? raw.replaceAll(_separators, ' ').trim()
      : segments.reduce((a, b) => b.length > a.length ? b : a);

  // Some panels use a dash instead of a pipe: `EN - Oppenheimer`. Only strip a
  // leading tag when a separator follows it, which is what makes it safe — a
  // bare leading word cannot be stripped, or films called `In Bruges` and
  // `No Country for Old Men` would lose their first word.
  var stripped = true;
  while (stripped) {
    stripped = false;
    final match = RegExp(r'^([A-Za-z]{2,6})\s*[-–:]\s+').firstMatch(text);
    if (match != null && _prefixNoise.contains(match.group(1)!.toLowerCase())) {
      text = text.substring(match.end).trim();
      stripped = true;
    }
  }

  // Bracketed years are unambiguous metadata wherever they sit.
  text = text.replaceAll(RegExp(r'[(\[]\s*(19|20)\d{2}\s*[)\]]'), ' ');
  text = text.replaceAll(_whitespace, ' ').trim();

  var words = text.split(' ').where((w) => w.isNotEmpty).toList();

  // Peel trailing junk: quality tags, separator dashes, and a corroborated
  // year. Looping because names stack them ("Scary Movie 4K - 2026").
  var changed = true;
  while (changed && words.length > 1) {
    changed = false;
    final last = words.last;
    final bare = last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (bare.isEmpty || last == '-' || last == '–') {
      words.removeLast();
      changed = true;
    } else if (_trailingNoise.contains(bare)) {
      words.removeLast();
      changed = true;
    } else if (_plausibleYear.hasMatch(bare)) {
      final value = int.parse(bare);
      if (year == null || (year - value).abs() <= 1) {
        words.removeLast();
        changed = true;
      }
    }
  }

  final out = words.join(' ').replaceAll(RegExp(r'[\s\-–]+$'), '').trim();
  // Never hand back nothing; a noisy title beats a blank one.
  return out.isEmpty ? raw.trim() : out;
}

bool _isNoiseSegment(String segment) {
  final words = segment
      .split(RegExp(r'[\s/,\-]+'))
      .map((w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  return words.every(_prefixNoise.contains);
}
