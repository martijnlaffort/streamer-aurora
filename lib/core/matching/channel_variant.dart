/// Splitting a provider's channel name into the channel and the quality it is
/// offered at, so the four rows a line ships for one channel can be shown as
/// one.
///
/// A real line lists `NL | NPO 1`, `NL | NPO 1 HD`, `NL | NPO 1 FHD` and
/// `NL | NPO 1 4K` as four separate channels. Collapsed, a 25k list becomes a
/// browsable one; left alone, the A–Z index and the guide are mostly the same
/// channel four times over.
///
/// The country/language tag is deliberately KEPT in the grouping key. Stripping
/// it the way `prettyTitle` does for films would merge `NL | Discovery` with
/// `UK | Discovery`, which are different channels showing different things.
library;

import 'name_tags.dart';

/// The name a channel sorts and indexes under — the provider's packaging taken
/// off the front, so the A–Z index and the alphabetical sort land on the word a
/// person actually reads. `|UCL| ZIGGO SPORT` sorts under Z, `:MLS 04` under M,
/// and `| PPV | The Fight` under T.
///
/// Leading only: trailing tags (`HD`, `[NL]`) are left alone, because they
/// distinguish one row from the next. Nothing here touches [ChannelVariant.key]
/// — grouping still keeps the country prefix, so `NL | Discovery` and
/// `UK | Discovery` never collapse into one row.
///
/// Falls back to the original when stripping would leave nothing, so a channel
/// that is ALL packaging still has something to sort on.
String channelSortName(String raw) {
  // Any leading bracketed tag (`|UCL|`, `[PPV]`, `«NL»`) is packaging for the
  // purpose of sorting; every one of them is noise here.
  var s = stripLeadingTag(raw, (_) => true);
  // Then a lone leading punctuation run with no closing partner — `:MLS 04`,
  // `- Sky Sports`, `. TNT` — which stripLeadingTag leaves untouched.
  s = s.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();
  return s.isEmpty ? raw.trim() : s;
}

/// Quality tags, lowercased and stripped of punctuation, with the rank used to
/// decide which variant a group plays by default.
///
/// An untagged channel sits between SD and HD ([untaggedRank]): a line that
/// bothers to write `HD` on one row and nothing on another is nearly always
/// distinguishing a better stream from a baseline one, but "no tag" is not
/// evidence of anything worse than SD.
const _qualities = <String, ({String label, int rank})>{
  '8k': (label: '8K', rank: 50),
  '4k': (label: '4K', rank: 40),
  'uhd': (label: '4K', rank: 40),
  '2160': (label: '4K', rank: 40),
  '2160p': (label: '4K', rank: 40),
  'fhd': (label: 'FHD', rank: 30),
  'fullhd': (label: 'FHD', rank: 30),
  '1080': (label: 'FHD', rank: 30),
  '1080p': (label: 'FHD', rank: 30),
  '1080i': (label: 'FHD', rank: 30),
  'hd': (label: 'HD', rank: 20),
  '720': (label: 'HD', rank: 20),
  '720p': (label: 'HD', rank: 20),
  'sd': (label: 'SD', rank: 10),
  '480': (label: 'SD', rank: 10),
  '480p': (label: 'SD', rank: 10),
  '576p': (label: 'SD', rank: 10),
};

/// Rank given to a channel with no quality tag at all.
const untaggedRank = 15;

/// Trailing tokens that say how a stream is encoded rather than which channel
/// it is. Dropped so `Foo FHD H265` and `Foo FHD` land in the same group, but
/// they never set the quality themselves.
const _codecNoise = {
  'hevc', 'h265', 'h264', 'x265', 'x264', 'avc', 'mpeg2', 'mpegts', 'ts',
};

/// Deliberately NOT stripped: `backup`, `alt`, `2`, `b` and friends. They look
/// like noise but routinely mark a genuinely different stream, and merging two
/// unrelated channels is a worse failure than leaving a duplicate row.
/// `+` survives into the key: it is load-bearing in channel names. Without it
/// `Canal+` collapses into `Canal` and `Film4 +1` into `Film4 1`, merging
/// channels that are genuinely different.
final _punctuation = RegExp(r'[^a-z0-9+]');
final _whitespace = RegExp(r'\s+');
final _trailingJunk = RegExp(r'[\s\-–—_:|/\\(\[\{]+$');

/// A channel name split into the channel and its quality.
class ChannelVariant {
  const ChannelVariant({
    required this.baseName,
    required this.qualityLabel,
    required this.qualityRank,
  });

  /// The name with the trailing quality/codec tags removed, and otherwise
  /// exactly as the provider wrote it — including any `NL |` prefix, so a
  /// collapsed row still reads the way the uncollapsed one did.
  final String baseName;

  /// `HD`, `FHD`, `4K`, `SD` — or null when the name carries no tag.
  final String? qualityLabel;

  /// Higher is better. Used to pick which variant a group plays.
  final int qualityRank;

  /// Grouping key: [baseName] reduced to letters and digits so punctuation and
  /// spacing differences between a line's own rows cannot split a group.
  String get key => baseName.toLowerCase().replaceAll(_punctuation, '');
}

/// Splits [rawName] into its channel and its quality.
///
/// Tags are only ever taken from the END of the name. `4K` in the middle can be
/// part of the channel itself, and a channel actually called `HD Cinema` must
/// survive with its name intact.
ChannelVariant parseChannelVariant(String rawName) {
  final tokens = rawName.replaceAll(_whitespace, ' ').trim().split(' ');
  String? label;
  int? rank;

  while (tokens.length > 1) {
    final bare = tokens.last.toLowerCase().replaceAll(_punctuation, '');
    if (bare.isEmpty) {
      tokens.removeLast();
      continue;
    }
    final quality = _qualities[bare];
    if (quality != null) {
      // First tag wins: in `Foo 4K HD` the rightmost is the afterthought, and
      // reading right-to-left means we meet it first.
      label ??= quality.label;
      rank ??= quality.rank;
      tokens.removeLast();
      continue;
    }
    if (_codecNoise.contains(bare)) {
      tokens.removeLast();
      continue;
    }
    break;
  }

  final base = tokens.join(' ').replaceAll(_trailingJunk, '').trim();
  return ChannelVariant(
    // A name that was nothing BUT tags keeps its original text: better a row
    // called `HD` than a row called nothing.
    baseName: base.isEmpty ? rawName.trim() : base,
    qualityLabel: label,
    qualityRank: rank ?? untaggedRank,
  );
}
