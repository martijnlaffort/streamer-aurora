/// Finding the streaming service hiding inside a provider's category name.
///
/// IPTV lines already organise VOD by service — `NL | NETFLIX`,
/// `MULTI | DISNEY+ 4K`, `| VOD | AMAZON PRIME NL` — but they do it in the
/// category NAME, so the app sees three unrelated strings where the viewer sees
/// one place they already think in ("what's on Netflix"). Recognising the brand
/// turns the line's own labelling into a browsable axis without asking the
/// provider for anything.
library;

import 'name_tags.dart';

/// A streaming service the catalogue might carry.
class ProviderBrand {
  const ProviderBrand({
    required this.id,
    required this.name,
    required this.aliases,
    required this.colorValue,
  });

  final String id;
  final String name;

  /// Lowercased, punctuation-free forms to look for. Longer ones win, so
  /// `disneyplus` is preferred over `disney` on the same name.
  final List<String> aliases;

  /// Brand-ish tile colour. Deliberately a colour rather than a logo: shipping
  /// the real marks would mean bundling other people's trademarks.
  final int colorValue;
}

/// Ordered longest-alias-first at match time, not here.
const kProviderBrands = <ProviderBrand>[
  ProviderBrand(
      id: 'netflix',
      name: 'Netflix',
      aliases: ['netflix', 'nflx'],
      colorValue: 0xFFE50914),
  ProviderBrand(
      id: 'disney',
      name: 'Disney+',
      aliases: ['disneyplus', 'disney+', 'disney'],
      colorValue: 0xFF113CCF),
  ProviderBrand(
      id: 'prime',
      name: 'Prime Video',
      aliases: ['primevideo', 'amazonprime', 'amazon', 'prime'],
      colorValue: 0xFF00A8E1),
  ProviderBrand(
      id: 'max',
      name: 'HBO Max',
      aliases: ['hbomax', 'hbo', 'max'],
      colorValue: 0xFF7B2BF9),
  ProviderBrand(
      id: 'appletv',
      name: 'Apple TV+',
      aliases: ['appletvplus', 'appletv+', 'appletv', 'apple'],
      colorValue: 0xFF1C1C1E),
  ProviderBrand(
      id: 'paramount',
      name: 'Paramount+',
      aliases: ['paramountplus', 'paramount+', 'paramount'],
      colorValue: 0xFF0064FF),
  ProviderBrand(
      id: 'skyshowtime',
      name: 'SkyShowtime',
      aliases: ['skyshowtime'],
      colorValue: 0xFF0B2A5B),
  ProviderBrand(
      id: 'viaplay',
      name: 'Viaplay',
      aliases: ['viaplay'],
      colorValue: 0xFFE3002B),
  ProviderBrand(
      id: 'videoland',
      name: 'Videoland',
      aliases: ['videoland'],
      colorValue: 0xFFE6007E),
  ProviderBrand(
      id: 'peacock',
      name: 'Peacock',
      aliases: ['peacock'],
      colorValue: 0xFF000000),
  ProviderBrand(
      id: 'hulu',
      name: 'Hulu',
      aliases: ['hulu'],
      colorValue: 0xFF1CE783),
  ProviderBrand(
      id: 'discovery',
      name: 'Discovery+',
      aliases: ['discoveryplus', 'discovery+', 'discovery'],
      colorValue: 0xFF0067B1),
  ProviderBrand(
      id: 'crunchyroll',
      name: 'Crunchyroll',
      aliases: ['crunchyroll'],
      colorValue: 0xFFF47521),
  ProviderBrand(
      id: 'npo',
      name: 'NPO',
      aliases: ['npostart', 'npo'],
      colorValue: 0xFFFF6600),
];

/// Tokens that are never a brand, but would otherwise be matched inside one.
/// `MAX` is the dangerous one: it is a real service AND a common word in
/// channel names, so it only counts as a brand when it stands alone.
const _standaloneOnly = {'max', 'apple', 'prime', 'amazon', 'discovery', 'hbo'};

final _nonAlnum = RegExp(r'[^a-z0-9+]+');

/// The service [categoryName] belongs to, or null.
///
/// Matches on whole words rather than substrings: without that, `MAX` finds
/// itself inside `CINEMAX` and a channel called `PRIMETIME` becomes Prime
/// Video. The tag brackets come off first so `| NETFLIX | 4K` matches the same
/// as `NETFLIX 4K`.
ProviderBrand? detectProviderBrand(String categoryName) {
  final cleaned = stripLeadingTag(categoryName, (_) => false);
  final words = cleaned
      .toLowerCase()
      .split(_nonAlnum)
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  final joined = words.join();

  ProviderBrand? best;
  var bestLength = 0;
  for (final brand in kProviderBrands) {
    for (final alias in brand.aliases) {
      final standalone = words.contains(alias);
      // A multi-word alias ("amazon prime" written as one token) is matched
      // against the whole name with separators removed.
      final glued = alias.length >= 6 && joined.contains(alias);
      final hit = _standaloneOnly.contains(alias) ? standalone : (standalone || glued);
      if (hit && alias.length > bestLength) {
        best = brand;
        bestLength = alias.length;
      }
    }
  }
  return best;
}
