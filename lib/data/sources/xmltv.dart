/// Streaming XMLTV parser (PRD §8.5). Real-provider guides run from tens to
/// hundreds of MB, so nothing here may hold the whole document: the streaming
/// entry point consumes text chunks and emits programmes as they complete.
/// Pure Dart — unit-testable.
///
/// XMLTV `<programme>` times look like `20260727180000 +0200`; they are
/// normalised to UTC here so the UTC-everywhere rule holds end to end.
library;

import 'package:xml/xml_events.dart';

import '../../domain/models/models.dart';

/// Event-by-event `<programme>` assembler shared by the string and streaming
/// parsers. Feed it XML events; it returns a completed [EpgEntry] whenever an
/// event closes a valid programme. Malformed programmes are skipped and
/// reported via [onSkip], never fatal.
class XmltvProgrammeAssembler {
  XmltvProgrammeAssembler({this.onSkip});

  final void Function(String message)? onSkip;

  String? _channel;
  DateTime? _start;
  DateTime? _stop;
  final _title = StringBuffer();
  final _desc = StringBuffer();
  String? _capture; // 'title' | 'desc' | null — which text we're collecting

  EpgEntry? feed(XmlEvent event) {
    if (event is XmlStartElementEvent) {
      switch (event.name) {
        case 'programme':
          _channel = _attr(event, 'channel');
          _start = _parseXmltvTime(_attr(event, 'start'));
          _stop = _parseXmltvTime(_attr(event, 'stop'));
          _title.clear();
          _desc.clear();
        case 'title':
          if (!event.isSelfClosing) _capture = 'title';
        case 'desc':
          if (!event.isSelfClosing) _capture = 'desc';
      }
    } else if (event is XmlTextEvent) {
      if (_capture == 'title') _title.write(event.value);
      if (_capture == 'desc') _desc.write(event.value);
    } else if (event is XmlCDATAEvent) {
      if (_capture == 'title') _title.write(event.value);
      if (_capture == 'desc') _desc.write(event.value);
    } else if (event is XmlEndElementEvent) {
      switch (event.name) {
        case 'title':
        case 'desc':
          _capture = null;
        case 'programme':
          final channel = _channel;
          final start = _start;
          final stop = _stop;
          _channel = null;
          _start = null;
          _stop = null;
          if (channel != null && start != null && stop != null) {
            final name = _title.toString().trim();
            final desc = _desc.toString().trim();
            return EpgEntry(
              channelId: channel,
              start: start,
              stop: stop,
              title: name.isEmpty ? 'No title' : name,
              description: desc.isEmpty ? null : desc,
            );
          }
          onSkip?.call('programme missing channel/start/stop');
      }
    }
    return null;
  }
}

/// Parses XMLTV [text] already held in memory. Only for small documents and
/// tests — production ingestion must use [parseXmltvStream] so the guide is
/// never materialised as one string.
List<EpgEntry> parseXmltv(String text, {void Function(String message)? onSkip}) {
  final assembler = XmltvProgrammeAssembler(onSkip: onSkip);
  final entries = <EpgEntry>[];
  for (final event in parseEvents(text)) {
    final entry = assembler.feed(event);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

/// Parses XMLTV from a stream of text [chunks] (e.g. a file read piped through
/// gzip/utf8 decoders), emitting programmes as they complete. Memory use is
/// bounded by one chunk + one programme regardless of guide size — this is
/// what makes a 100+ MB provider guide safe to ingest on a phone.
Stream<EpgEntry> parseXmltvStream(Stream<String> chunks,
    {void Function(String message)? onSkip}) async* {
  final assembler = XmltvProgrammeAssembler(onSkip: onSkip);
  await for (final events in chunks.toXmlEvents()) {
    for (final event in events) {
      final entry = assembler.feed(event);
      if (entry != null) yield entry;
    }
  }
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
  // tells us how to shift to UTC. The XMLTV spec puts a space before the
  // offset, but plenty of real providers omit it ("20260727180000+0200"), so
  // take everything after the 14-digit datetime and trim — don't assume a
  // fixed position, or a spaceless offset gets dropped and the time is wrong by
  // the panel's UTC offset.
  var utc = DateTime.utc(year, month, day, hour, minute, second);
  final tz = s.substring(14).trim();
  if (tz.length >= 5 && (tz.startsWith('+') || tz.startsWith('-'))) {
    final sign = tz[0] == '-' ? -1 : 1;
    final offH = int.tryParse(tz.substring(1, 3)) ?? 0;
    final offM = int.tryParse(tz.substring(3, 5)) ?? 0;
    utc = utc.subtract(Duration(hours: sign * offH, minutes: sign * offM));
  }
  return utc;
}
