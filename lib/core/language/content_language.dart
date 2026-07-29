import 'package:equatable/equatable.dart';

/// A detected content-language bucket for a catalog category.
///
/// IPTV/Xtream panels encode language on the *category* ("NL | Films",
/// "EN - Movies", "🇩🇪 Serien", "VOD | AR | Movies"), never on the individual
/// title — so this is a best-effort parse of that naming convention. Anything
/// unrecognised falls into [ContentLanguage.other] so it stays visible and
/// toggleable rather than silently hidden.
class ContentLanguage extends Equatable {
  const ContentLanguage(this.code, this.label);

  /// Stable bucket key (e.g. 'EN', 'NL', 'OTHER') — persisted in preferences.
  final String code;

  /// Human label for the picker (e.g. 'English').
  final String label;

  static const other = ContentLanguage('OTHER', 'Other');

  @override
  List<Object?> get props => [code];

  @override
  bool get stringify => true;
}

/// Bucket code → display label.
const _bucketLabels = <String, String>{
  'EN': 'English',
  'NL': 'Dutch',
  'DE': 'German',
  'FR': 'French',
  'ES': 'Spanish',
  'IT': 'Italian',
  'TR': 'Turkish',
  'AR': 'Arabic',
  'PT': 'Portuguese',
  'PL': 'Polish',
  'RU': 'Russian',
  'SE': 'Swedish',
  'NO': 'Norwegian',
  'DK': 'Danish',
  'FI': 'Finnish',
  'GR': 'Greek',
  'RO': 'Romanian',
  'AL': 'Albanian',
  'EXYU': 'Ex-YU',
  'IN': 'Hindi',
  'HU': 'Hungarian',
  'CZ': 'Czech',
  'PK': 'Urdu',
};

/// Token (language word or country code) → bucket code. Country codes map to
/// the language most IPTV playlists mean by them (US/UK → English, AR → Arabic
/// rather than Argentina, etc.).
const _tokenToBucket = <String, String>{
  // English
  'EN': 'EN', 'ENG': 'EN', 'ENGLISH': 'EN', 'UK': 'EN', 'GB': 'EN',
  'US': 'EN', 'USA': 'EN', 'AU': 'EN', 'CA': 'EN', 'IE': 'EN', 'NZ': 'EN',
  'AMERICAN': 'EN', 'BRITISH': 'EN',
  // Dutch (incl. Flemish)
  'NL': 'NL', 'NLD': 'NL', 'NED': 'NL', 'DUTCH': 'NL', 'HOLLAND': 'NL',
  'NEDERLAND': 'NL', 'NEDERLANDS': 'NL', 'HOLLANDSE': 'NL', 'VLAAMS': 'NL',
  'BE': 'NL',
  // German
  'DE': 'DE', 'GER': 'DE', 'DEU': 'DE', 'GERMAN': 'DE', 'DEUTSCH': 'DE',
  'DEUTSCHLAND': 'DE', 'AT': 'DE',
  // French
  'FR': 'FR', 'FRA': 'FR', 'FRENCH': 'FR', 'FRANCE': 'FR', 'FRANCAIS': 'FR',
  // Spanish
  'ES': 'ES', 'ESP': 'ES', 'SPANISH': 'ES', 'ESPANA': 'ES', 'ESPANOL': 'ES',
  'LATINO': 'ES', 'LATIN': 'ES', 'MX': 'ES', 'MEXICO': 'ES',
  // Italian
  'IT': 'IT', 'ITA': 'IT', 'ITALIAN': 'IT', 'ITALIANO': 'IT', 'ITALIA': 'IT',
  // Turkish
  'TR': 'TR', 'TUR': 'TR', 'TURKISH': 'TR', 'TURK': 'TR', 'TURKIYE': 'TR',
  // Arabic
  'AR': 'AR', 'ARA': 'AR', 'ARABIC': 'AR', 'ARAB': 'AR', 'EGY': 'AR',
  'KSA': 'AR', 'UAE': 'AR', 'MSA': 'AR',
  // Portuguese (incl. Brazil)
  'PT': 'PT', 'POR': 'PT', 'PORTUGUESE': 'PT', 'PORTUGUES': 'PT',
  'PORTUGAL': 'PT', 'BR': 'PT', 'BRA': 'PT', 'BRAZIL': 'PT', 'BRASIL': 'PT',
  // Polish
  'PL': 'PL', 'POL': 'PL', 'POLISH': 'PL', 'POLSKA': 'PL',
  // Russian
  'RU': 'RU', 'RUS': 'RU', 'RUSSIAN': 'RU', 'RUSSIA': 'RU',
  // Nordic
  'SE': 'SE', 'SWE': 'SE', 'SWEDISH': 'SE', 'SVENSKA': 'SE',
  'NO': 'NO', 'NOR': 'NO', 'NORWEGIAN': 'NO', 'NORSK': 'NO',
  'DK': 'DK', 'DAN': 'DK', 'DANISH': 'DK', 'DANSK': 'DK',
  'FI': 'FI', 'FIN': 'FI', 'FINNISH': 'FI', 'SUOMI': 'FI',
  // Greek
  'GR': 'GR', 'GRE': 'GR', 'GREEK': 'GR', 'ELLADA': 'GR',
  // Romanian
  'RO': 'RO', 'ROM': 'RO', 'ROMANIAN': 'RO', 'ROMANIA': 'RO',
  // Albanian
  'AL': 'AL', 'ALB': 'AL', 'ALBANIAN': 'AL', 'SHQIP': 'AL',
  // Ex-Yugoslav / Balkan
  'EXYU': 'EXYU', 'YU': 'EXYU', 'BALKAN': 'EXYU', 'YUGO': 'EXYU', 'RS': 'EXYU',
  'SRB': 'EXYU', 'HR': 'EXYU', 'CRO': 'EXYU', 'BA': 'EXYU', 'SI': 'EXYU',
  'MK': 'EXYU',
  // Hindi / Indian
  'IN': 'IN', 'IND': 'IN', 'HINDI': 'IN', 'INDIAN': 'IN', 'DESI': 'IN',
  'BOLLYWOOD': 'IN',
  // Others
  'HU': 'HU', 'HUN': 'HU', 'HUNGARIAN': 'HU', 'MAGYAR': 'HU',
  'CZ': 'CZ', 'CZE': 'CZ', 'CZECH': 'CZ',
  'PK': 'PK', 'URDU': 'PK', 'PAKISTAN': 'PK',
};

/// Segment separators panels put between the language prefix and the rest.
/// A bare hyphen is deliberately excluded so genre words like "Sci-Fi" aren't
/// split into a stray "FI" — only a *spaced* dash ("EN - Movies") counts.
final _strongSeparators = RegExp(r'[|/:›»>]|\s[-–—]\s');
final _nonAlnum = RegExp(r'[^A-Z0-9]+');

/// Best-effort language of a category, from its name. Never null — unknowns
/// return [ContentLanguage.other].
ContentLanguage detectContentLanguage(String name) {
  // 1) A flag emoji anywhere is the strongest signal → country → bucket.
  final country = _flagCountry(name);
  if (country != null) {
    final bucket = _tokenToBucket[country];
    if (bucket != null) return ContentLanguage(bucket, _bucketLabels[bucket]!);
  }

  // Uppercase and fold diacritics so "Türk"/"Español"/"Português" tokenize as
  // TURK/ESPANOL/PORTUGUES instead of shattering on the accented letter.
  final upper = _fold(name.toUpperCase());

  // 2) Multi-word buckets a naive split would break.
  if (upper.contains('EX-YU') || upper.contains('EX YU')) {
    return const ContentLanguage('EXYU', 'Ex-YU');
  }

  // 3) A whole segment that *is* a code/word is a confident prefix, even when
  //    otherwise ambiguous ("VOD | DE | Filme" → German).
  for (final seg in upper.split(_strongSeparators)) {
    final bucket = _tokenToBucket[seg.trim()];
    if (bucket != null) return ContentLanguage(bucket, _bucketLabels[bucket]!);
  }

  // 4) Word scan for names without clear separators ("Dutch Movies"). Only the
  //    leading word may be a short 2-letter code — a later "FI" (Sci-Fi), "de"
  //    (Spanish) or "in" (English) is noise, not a prefix.
  final tokens =
      upper.split(_nonAlnum).where((t) => t.isNotEmpty).toList(growable: false);
  for (var i = 0; i < tokens.length; i++) {
    final bucket = _tokenToBucket[tokens[i]];
    if (bucket == null) continue;
    if (i > 0 && tokens[i].length <= 2) continue;
    return ContentLanguage(bucket, _bucketLabels[bucket]!);
  }

  return ContentLanguage.other;
}

/// Folds common (uppercase) Latin diacritics to ASCII so accented language
/// words survive tokenizing.
const _diacritics = <String, String>{
  'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
  'Ç': 'C', 'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
  'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I', 'İ': 'I',
  'Ñ': 'N', 'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'Ø': 'O',
  'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U', 'Ý': 'Y',
  'Ğ': 'G', 'Ş': 'S', 'Š': 'S', 'Ž': 'Z', 'Ć': 'C', 'Č': 'C',
};

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString();
}

/// Decodes the first regional-indicator pair (a flag emoji) to its ISO 3166
/// alpha-2 country code, or null if the string has no flag.
String? _flagCountry(String s) {
  final runes = s.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    final a = runes[i], b = runes[i + 1];
    if (a >= 0x1F1E6 && a <= 0x1F1FF && b >= 0x1F1E6 && b <= 0x1F1FF) {
      return String.fromCharCode(a - 0x1F1E6 + 0x41) +
          String.fromCharCode(b - 0x1F1E6 + 0x41);
    }
  }
  return null;
}
