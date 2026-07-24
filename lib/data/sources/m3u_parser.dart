/// Pure-Dart M3U/EXTINF playlist parser (PRD §6.2). No Flutter, no I/O —
/// text in, entries out — so it is trivially unit-testable. Malformed lines
/// are skipped and reported via callback, never fatal (global rule).
library;

/// One playlist entry: an `#EXTINF` line plus its URL line.
class M3uEntry {
  const M3uEntry({
    required this.name,
    required this.url,
    required this.attributes,
  });

  final String name;
  final String url;

  /// Raw `key="value"` attributes from the EXTINF line (tvg-id, tvg-name,
  /// tvg-logo, group-title, ...). Keys are lowercased.
  final Map<String, String> attributes;

  String? get tvgId => _nonEmpty('tvg-id');
  String? get tvgLogo => _nonEmpty('tvg-logo');
  String? get groupTitle => _nonEmpty('group-title');

  String? _nonEmpty(String key) {
    final v = attributes[key]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}

class M3uPlaylist {
  const M3uPlaylist({
    required this.entries,
    this.epgUrl,
    this.sawHeader = false,
  });

  final List<M3uEntry> entries;

  /// From `url-tvg=`/`x-tvg-url=` on the `#EXTM3U` header, when present.
  final String? epgUrl;

  /// Whether a `#EXTM3U` header line was seen (used to judge "is this even
  /// an M3U file" — some real-world playlists do omit it).
  final bool sawHeader;
}

final _attrPattern = RegExp(r'([A-Za-z0-9_.\-]+)="([^"]*)"');

/// Parses playlist [text]. Lines that cannot be interpreted are reported to
/// [onSkippedLine] (1-based line number + reason) and skipped.
M3uPlaylist parseM3u(String text, {void Function(String message)? onSkippedLine}) {
  void skip(int lineNo, String reason) => onSkippedLine?.call('line $lineNo: $reason');

  final entries = <M3uEntry>[];
  String? epgUrl;
  var sawHeader = false;

  // Pending EXTINF state, waiting for its URL line.
  String? pendingName;
  Map<String, String>? pendingAttrs;
  int pendingLine = 0;

  final lines = text.replaceFirst('﻿', '').split(RegExp(r'\r?\n'));
  for (final (i, rawLine) in lines.indexed) {
    final lineNo = i + 1;
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTM3U')) {
      sawHeader = true;
      for (final m in _attrPattern.allMatches(line)) {
        final key = m.group(1)!.toLowerCase();
        if ((key == 'url-tvg' || key == 'x-tvg-url') && m.group(2)!.isNotEmpty) {
          epgUrl = m.group(2);
        }
      }
      continue;
    }

    if (line.startsWith('#EXTINF:')) {
      if (pendingAttrs != null) {
        skip(pendingLine, '#EXTINF without a URL line');
      }
      final content = line.substring('#EXTINF:'.length);
      final attrs = <String, String>{};
      var attrsEnd = 0;
      for (final m in _attrPattern.allMatches(content)) {
        attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
        attrsEnd = m.end;
      }
      // The display name follows the first comma AFTER the attribute block —
      // names themselves may contain commas, so don't split naively.
      final commaIdx = content.indexOf(',', attrsEnd);
      final title = commaIdx >= 0 ? content.substring(commaIdx + 1).trim() : '';
      pendingName = title;
      pendingAttrs = attrs;
      pendingLine = lineNo;
      continue;
    }

    // Some playlists carry the group on a separate #EXTGRP line.
    if (line.startsWith('#EXTGRP:')) {
      final group = line.substring('#EXTGRP:'.length).trim();
      if (pendingAttrs != null && group.isNotEmpty) {
        pendingAttrs.putIfAbsent('group-title', () => group);
      }
      continue;
    }

    // Any other directive/comment: ignore.
    if (line.startsWith('#')) continue;

    // A bare (non-comment) line is a stream URL.
    if (pendingAttrs == null) {
      skip(lineNo, 'URL without a preceding #EXTINF');
      continue;
    }
    final name = (pendingName != null && pendingName.isNotEmpty)
        ? pendingName
        : (pendingAttrs['tvg-name']?.trim().isNotEmpty ?? false)
            ? pendingAttrs['tvg-name']!.trim()
            : 'Unnamed';
    entries.add(M3uEntry(name: name, url: line, attributes: pendingAttrs));
    pendingName = null;
    pendingAttrs = null;
  }

  if (pendingAttrs != null) {
    skip(pendingLine, '#EXTINF without a URL line');
  }

  return M3uPlaylist(entries: entries, epgUrl: epgUrl, sawHeader: sawHeader);
}

/// Stable 32-bit FNV-1a hash as hex — used for entry ids. M3U entries have no
/// panel-assigned id, and `tvg-id` is often missing or duplicated, so the
/// stream URL (unique and stable across refreshes) is the identity.
String stableId(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
