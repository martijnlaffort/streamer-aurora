/// Streaming XMLTV parser (PRD §8.5). Full guides can be tens of MB, so this
/// parses events rather than building a DOM. Pure Dart — unit-testable.
///
/// XMLTV `<programme>` times look like `20260727180000 +0200`; they are
/// normalised to UTC here so the UTC-everywhere rule holds end to end.
library;

import 'package:xml/xml_events.dart';

import '../../domain/models/models.dart';

/// Parses XMLTV [text] into EPG entries keyed by the programme's `channel`
/// attribute (which matches a channel's tvg-id / epgChannelId). Malformed
/// programmes are skipped and reported via [onSkip], never fatal.
List<EpgEntry> parseXmltv(String text, {void Function(String message)? onSkip}) {
  final entries = <EpgEntry>[];

  String? channel;
  DateTime? start;
  DateTime? stop;
  final title = StringBuffer();
  final desc = StringBuffer();
  String? capture; // 'title' | 'desc' | null — which text we're collecting

  for (final event in parseEvents(text)) {
    if (event is XmlStartElementEvent) {
      switch (event.name) {
        case 'programme':
          channel = _attr(event, 'channel');
          start = _parseXmltvTime(_attr(event, 'start'));
          stop = _parseXmltvTime(_attr(event, 'stop'));
          title.clear();
          desc.clear();
        case 'title':
          if (!event.isSelfClosing) capture = 'title';
        case 'desc':
          if (!event.isSelfClosing) capture = 'desc';
      }
    } else if (event is XmlTextEvent) {
      if (capture == 'title') title.write(event.value);
      if (capture == 'desc') desc.write(event.value);
    } else if (event is XmlCDATAEvent) {
      if (capture == 'title') title.write(event.value);
      if (capture == 'desc') desc.write(event.value);
    } else if (event is XmlEndElementEvent) {
      switch (event.name) {
        case 'title':
        case 'desc':
          capture = null;
        case 'programme':
          if (channel != null && start != null && stop != null) {
            final name = title.toString().trim();
            entries.add(EpgEntry(
              channelId: channel,
              start: start,
              stop: stop,
              title: name.isEmpty ? 'No title' : name,
              description:
                  desc.toString().trim().isEmpty ? null : desc.toString().trim(),
            ));
          } else {
            onSkip?.call('programme missing channel/start/stop');
          }
          channel = null;
          start = null;
          stop = null;
      }
    }
  }
  return entries;
}

String? _attr(XmlStartElementEvent event, String name) {
  for (final a in event.attributes) {
    if (a.name == name) return a.value;
  }
  return null;
}

/// `20260727180000 +0200` / `20260727180000` → UTC DateTime. Returns null on
/// anything unparseable.
DateTime? _parseXmltvTime(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.length < 14) return null;
  final year = int.tryParse(s.substring(0, 4));
  final month = int.tryParse(s.substring(4, 6));
  final day = int.tryParse(s.substring(6, 8));
  final hour = int.tryParse(s.substring(8, 10));
  final minute = int.tryParse(s.substring(10, 12));
  final second = int.tryParse(s.substring(12, 14));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  // Base is the wall-clock time; the trailing "+HHMM"/"-HHMM" offset (if any)
  // tells us how to shift to UTC.
  var utc = DateTime.utc(year, month, day, hour, minute, second);
  final tz = s.length >= 20 ? s.substring(15, 20) : null;
  if (tz != null && (tz.startsWith('+') || tz.startsWith('-'))) {
    final sign = tz[0] == '-' ? -1 : 1;
    final offH = int.tryParse(tz.substring(1, 3)) ?? 0;
    final offM = int.tryParse(tz.substring(3, 5)) ?? 0;
    utc = utc.subtract(Duration(hours: sign * offH, minutes: sign * offM));
  }
  return utc;
}
