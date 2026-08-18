import 'package:dawnplayer/data/sources/xmltv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseXmltv', () {
    test('parses programmes, converting the timezone offset to UTC', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="npo1.nl"><display-name>NPO 1</display-name></channel>
  <programme start="20260727180000 +0200" stop="20260727190000 +0200" channel="npo1.nl">
    <title lang="nl">Journaal</title>
    <desc>Het nieuws.</desc>
  </programme>
</tv>''';
      final entries = parseXmltv(xml);
      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.channelId, 'npo1.nl');
      expect(e.title, 'Journaal');
      expect(e.description, 'Het nieuws.');
      // 18:00 +0200 == 16:00 UTC.
      expect(e.start, DateTime.utc(2026, 7, 27, 16));
      expect(e.stop, DateTime.utc(2026, 7, 27, 17));
      expect(e.start.isUtc, isTrue);
    });

    test('handles a negative offset and a no-offset (already UTC) time', () {
      const xml = '''
<tv>
  <programme start="20260727120000 -0500" stop="20260727130000 -0500" channel="a">
    <title>West</title>
  </programme>
  <programme start="20260727120000" stop="20260727130000" channel="b">
    <title>Bare</title>
  </programme>
</tv>''';
      final entries = parseXmltv(xml);
      // 12:00 -0500 == 17:00 UTC.
      expect(entries[0].start, DateTime.utc(2026, 7, 27, 17));
      // No offset → treated as UTC.
      expect(entries[1].start, DateTime.utc(2026, 7, 27, 12));
    });

    test('CDATA titles/descriptions are captured', () {
      const xml = '''
<tv>
  <programme start="20260727120000 +0000" stop="20260727130000 +0000" channel="c">
    <title><![CDATA[Movie & Show]]></title>
  </programme>
</tv>''';
      expect(parseXmltv(xml).single.title, 'Movie & Show');
    });

    test('skips programmes missing channel/start/stop, never crashes', () {
      const xml = '''
<tv>
  <programme start="20260727120000 +0000" channel="c"><title>No stop</title></programme>
  <programme stop="20260727130000 +0000" channel="c"><title>No start</title></programme>
  <programme start="20260727120000 +0000" stop="20260727130000 +0000"><title>No channel</title></programme>
  <programme start="20260727140000 +0000" stop="20260727150000 +0000" channel="c"><title>Good</title></programme>
</tv>''';
      final skipped = <String>[];
      final entries = parseXmltv(xml, onSkip: skipped.add);
      expect(entries.map((e) => e.title), ['Good']);
      expect(skipped, hasLength(3));
    });

    test('empty title falls back rather than being blank', () {
      const xml = '''
<tv>
  <programme start="20260727120000 +0000" stop="20260727130000 +0000" channel="c"></programme>
</tv>''';
      expect(parseXmltv(xml).single.title, 'No title');
    });
  });
}
