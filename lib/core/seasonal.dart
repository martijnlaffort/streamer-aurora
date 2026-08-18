/// Date-driven rails: horror in October, Christmas films in December.
///
/// The cheapest good idea in the whole discovery story. Every streaming service
/// does this, it needs no external data of any kind — no key, no network, no
/// licence, nothing that can be priced or revoked — and it works entirely from
/// the catalogue the user already has.
///
/// A season is matched against the panel's own `genre` string and the title,
/// because panels are wildly inconsistent about which of the two carries the
/// signal: Christmas films are almost never genre-tagged as such but nearly
/// always say so in the title, while horror is the reverse.
library;

class Season {
  const Season({
    required this.id,
    required this.label,
    required this.from,
    required this.to,
    this.genreKeywords = const [],
    this.titleKeywords = const [],
  });

  final String id;

  /// Rail heading. Written as an invitation rather than a category name —
  /// "Something to be scared by" reads better on a sofa than "Horror".
  final String label;

  /// Inclusive (month, day) bounds. A season may wrap the new year.
  final (int, int) from;
  final (int, int) to;

  final List<String> genreKeywords;
  final List<String> titleKeywords;

  bool contains(DateTime date) {
    final md = date.month * 100 + date.day;
    final start = from.$1 * 100 + from.$2;
    final end = to.$1 * 100 + to.$2;
    // A season that wraps December into January is two ranges, not one.
    return start <= end
        ? md >= start && md <= end
        : md >= start || md <= end;
  }
}

/// Deliberately few. A seasonal rail earns attention by being unusual, so one
/// that is always present is just another category row.
const seasons = <Season>[
  Season(
    id: 'valentines',
    label: 'For Valentine\'s Night',
    from: (2, 5),
    to: (2, 15),
    genreKeywords: ['romance', 'romantic'],
    titleKeywords: ['love'],
  ),
  Season(
    id: 'summer',
    label: 'Summer Blockbusters',
    from: (6, 15),
    to: (8, 31),
    genreKeywords: ['action', 'adventure', 'sci-fi', 'science fiction'],
  ),
  Season(
    id: 'halloween',
    label: 'Something To Be Scared By',
    from: (10, 1),
    to: (11, 1),
    genreKeywords: ['horror', 'thriller'],
    titleKeywords: ['halloween'],
  ),
  Season(
    id: 'christmas',
    label: 'Christmas Films',
    from: (12, 1),
    to: (12, 27),
    // Dutch included: this catalogue is a Dutch line, and "Kerst" is how half
    // of these are actually titled on it.
    titleKeywords: ['christmas', 'kerst', 'santa', 'xmas'],
  ),
];

/// The season for [date], or null for most of the year — which is the point.
Season? seasonFor(DateTime date) {
  for (final season in seasons) {
    if (season.contains(date)) return season;
  }
  return null;
}
