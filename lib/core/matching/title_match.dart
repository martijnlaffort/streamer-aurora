/// Matching panel titles against external title lists (TMDB, the bundled award
/// canon).
///
/// IPTV titles are not clean: a panel will happily call the same film
/// `Oppenheimer`, `Oppenheimer (2023)`, `EN - Oppenheimer 4K`, or
/// `VOD| Oppenheimer 2023 MULTi 1080p`. Matching on the raw string finds almost
/// nothing, so both sides are reduced to a comparable key first.
library;

/// Tokens panels bolt onto names: quality, source, codec, language and channel
/// prefixes. Stripped as whole words only, so `Her` survives `HDR` handling and
/// a film legitimately called `Ted` is not mangled.
const _noiseWords = {
  '4k', 'uhd', 'hd', 'sd', 'fhd', 'hq', 'lq', '1080p', '1080i', '720p', '480p',
  '2160p', 'bluray', 'blueray', 'brrip', 'bdrip', 'webrip', 'web', 'webdl',
  'hdrip', 'dvdrip', 'dvd', 'cam', 'ts', 'hdts', 'telesync', 'r5', 'proper',
  'repack', 'remux', 'hdr', 'hdr10', 'dv', 'dolby', 'vision', 'atmos',
  'x264', 'x265', 'h264', 'h265', 'hevc', 'avc', 'aac', 'ac3', 'dts', 'ddp',
  'ddp5', 'truehd', 'xvid', 'divx', 'sdr', '10bit', '8bit', 'hdcam',
  'multi', 'multisub', 'multisubs', 'dual', 'dubbed', 'subbed', 'sub', 'subs',
  'vostfr', 'truefrench', 'vf', 'vo', 'vff', 'imax', 'extended', 'unrated',
  'remastered', 'directors', 'director', 'cut', 'theatrical', 'vod', 'movie',
  'film',
  // `WEB-DL` splits into two tokens once punctuation goes, leaving a bare `dl`;
  // likewise the streaming-service source tags panels append.
  'dl', 'amzn', 'nf', 'dsnp', 'hmax', 'atvp', 'hulu', 'pcok',
};

/// Two-letter/three-letter language tags panels prefix names with (`EN -`,
/// `NL|`, `FR:`). Only stripped from the START, where they are unambiguous —
/// `it` or `no` mid-title are real words.
const _languagePrefixes = {
  'en', 'eng', 'nl', 'ned', 'dut', 'fr', 'fra', 'fre', 'de', 'ger', 'deu',
  'es', 'esp', 'spa', 'it', 'ita', 'pt', 'por', 'br', 'tr', 'tur', 'ar', 'ara',
  'ru', 'rus', 'pl', 'pol', 'ro', 'ron', 'se', 'swe', 'no', 'nor', 'dk', 'dan',
  'fi', 'fin', 'gr', 'ell', 'hu', 'hun', 'cz', 'ces', 'sk', 'al', 'alb', 'ex',
  'usa', 'uk', 'us', 'ca', 'au', 'in', 'hin', 'lat', 'latino', 'vip',
};

/// Roman numerals worth folding to digits so `Rocky II` meets `Rocky 2`.
const _romanNumerals = {
  'ii': '2', 'iii': '3', 'iv': '4', 'v': '5', 'vi': '6', 'vii': '7',
  'viii': '8', 'ix': '9', 'x': '10',
};

/// A *bracketed* year: `Dune (2021)`, `Dune [2021]`. Unambiguously metadata, so
/// it is always safe to strip.
final _bracketedYear = RegExp(r'[(\[]\s*((?:19|20)\d{2})\s*[)\]]');

/// A bare trailing year: `Dune 2021`. NOT safe to strip unconditionally — see
/// [normalizeTitle]; `Blade Runner 2049` would become `Blade Runner` and collide
/// with the 1982 film.
final _trailingYear = RegExp(r'\s((?:19|20)\d{2})$');

/// Everything that is not a letter, digit or space, after diacritic folding.
final _punctuation = RegExp(r'[^a-z0-9 ]');
final _whitespace = RegExp(r'\s+');

/// Diacritic folding for the Latin-1/Latin-2 range panels actually emit, plus
/// the handful of non-Latin cases that show up in titles (`Shōgun`, `Amélie`).
const _foldings = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ø': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ñ': 'n', 'ń': 'n', 'ş': 's', 'š': 's',
  'ž': 'z', 'ź': 'z', 'ý': 'y', 'ÿ': 'y', 'ğ': 'g', 'ł': 'l', 'ř': 'r',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ð': 'd', 'þ': 'th', 'ı': 'i',
};

/// Reduces a title to a comparison key: lowercased, diacritic-folded,
/// punctuation-free, with release-quality noise, language prefixes and a leading
/// article removed.
///
/// [knownYear] governs the one genuinely ambiguous case: a bare trailing year.
/// It is stripped only when it *corroborates* the year we already have — then it
/// is redundant metadata (`Oppenheimer 2023`, year 2023). When it disagrees, the
/// number is part of the name and is kept, which is what keeps `Blade Runner
/// 2049` (year 2017) from collapsing onto `Blade Runner` (1982). Bracketed years
/// are always metadata and always go.
///
/// Returns an empty string when nothing survives (a name that was *only* noise),
/// which callers must treat as unmatchable rather than as a wildcard.
String normalizeTitle(String raw, {int? knownYear}) {
  var s = raw.toLowerCase();

  // Panels use these as field separators before the real name: `EN - Name`,
  // `NL| Name`, `[VIP] Name`. Split on them and keep the longest part, which is
  // overwhelmingly the title itself.
  s = s.replaceAll('|', ' ').replaceAll('•', ' ').replaceAll('·', ' ');

  final folded = StringBuffer();
  for (final ch in s.split('')) {
    folded.write(_foldings[ch] ?? ch);
  }
  s = folded.toString();

  s = s.replaceAll(_bracketedYear, ' ');
  // Apostrophes are DELETED, not spaced: panels drop them freely, so
  // `Schindler's List` and `Schindlers List` must reduce to the same key.
  s = s.replaceAll("'", '').replaceAll('’', '').replaceAll('`', '');
  s = s.replaceAll(_punctuation, ' ');
  s = s.replaceAll(_whitespace, ' ').trim();
  if (s.isEmpty) return '';

  var words = s.split(' ');

  // Leading language/region tag, at most one.
  if (words.length > 1 && _languagePrefixes.contains(words.first)) {
    words = words.sublist(1);
  }

  words = [
    for (final w in words)
      if (!_noiseWords.contains(w)) _romanNumerals[w] ?? w,
  ];

  // A leading article carries no identity and panels are inconsistent about it.
  if (words.length > 1 &&
      const {'the', 'a', 'an', 'de', 'het', 'le', 'la', 'les', 'el', 'il'}
          .contains(words.first)) {
    words = words.sublist(1);
  }

  var out = words.join(' ');

  // Noise removal can leave the year at the end (`oppenheimer 2023 4k multi` →
  // `oppenheimer 2023`), so this runs last.
  final trailing = _trailingYear.firstMatch(out);
  if (trailing != null && words.length > 1) {
    final value = int.parse(trailing.group(1)!);
    // Strip only when it is redundant metadata: it agrees with the year we were
    // given, or we had none and are about to take this as the year anyway.
    if (knownYear == null || (knownYear - value).abs() <= 1) {
      out = out.substring(0, trailing.start).trim();
    }
  }
  return out;
}

/// The release year a panel tacked onto a title, if any.
///
/// Only a year at the very END counts (`Dune 2021`, `Dune (2021)`). A year
/// elsewhere is usually part of the name — `2001: A Space Odyssey`,
/// `Live Aid 1985 Concert` — and treating it as metadata mismatches the film.
int? extractYear(String raw) {
  final trimmed = raw.trim();
  final match =
      RegExp(r'[\s(\[]((?:19|20)\d{2})[)\]]?$').firstMatch(trimmed);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// A catalogue entry reduced to its matching key.
class TitleKey {
  const TitleKey(this.normalized, this.year);

  final String normalized;
  final int? year;

  /// Whether this refers to the same title as [other].
  ///
  /// Years must agree within [yearTolerance] when BOTH are known: panels and
  /// TMDB routinely disagree by a year (festival vs general release, or a
  /// December film catalogued as the next year). When either side has no year we
  /// accept the name match alone — for distinctive names that is right, and it
  /// is the only option when the panel gives no year at all.
  bool matches(TitleKey other, {int yearTolerance = 1}) {
    if (normalized.isEmpty || other.normalized.isEmpty) return false;
    if (normalized != other.normalized) return false;
    final a = year, b = other.year;
    if (a == null || b == null) return true;
    return (a - b).abs() <= yearTolerance;
  }
}

/// Builds the matching key for a catalogue row. [year] is the panel's own year
/// column when it has one; a year found in the name is the fallback.
TitleKey titleKeyFor(String name, {int? year}) {
  final resolvedYear = year ?? extractYear(name);
  return TitleKey(normalizeTitle(name, knownYear: resolvedYear), resolvedYear);
}
