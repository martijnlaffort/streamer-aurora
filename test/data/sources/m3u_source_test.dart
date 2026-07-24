import 'dart:io';

import 'package:aurora/data/sources/m3u_parser.dart';
import 'package:aurora/data/sources/m3u_source.dart';
import 'package:aurora/data/sources/playlist_source.dart';
import 'package:aurora/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 1, 1, 12);

  Account account(String path) => Account(
        id: 'm3u1',
        type: AccountType.m3u,
        name: 'Test M3U',
        serverUrl: path,
        username: '',
        password: '',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  (M3uSource, List<String>) build(String path, {String? epgUrl}) {
    final skipped = <String>[];
    final source = M3uSource(
      account: account(path),
      epgUrl: epgUrl,
      clock: () => fixedNow,
      onSkippedRow: skipped.add,
    );
    return (source, skipped);
  }

  group('parser', () {
    test('parses attributes, EXTGRP, header EPG url, comma-in-name', () {
      final text =
          File('test/fixtures/m3u/live_only.m3u').readAsStringSync();
      final playlist = parseM3u(text);

      expect(playlist.sawHeader, isTrue);
      expect(playlist.epgUrl, 'http://epg.example.com/guide.xml');
      expect(playlist.entries, hasLength(5));

      final npo = playlist.entries[0];
      expect(npo.name, 'NPO 1 HD');
      expect(npo.tvgId, 'npo1.nl');
      expect(npo.tvgLogo, 'http://logo.example.com/npo1.png');
      expect(npo.groupTitle, 'NL | Algemeen');
      expect(npo.url, 'http://stream.example.com/npo1/index.m3u8');

      // Display names may contain commas — must not be split on them.
      expect(playlist.entries[2].name, 'Formula 1: Practice, Qualifying & Race');
      // Empty tvg-id attribute normalizes to null.
      expect(playlist.entries[2].tvgId, isNull);
      // Attribute-less EXTINF still yields a named entry.
      expect(playlist.entries[3].name, 'No Attrs Channel');
      expect(playlist.entries[3].groupTitle, isNull);
      // #EXTGRP supplies the group when the attribute is absent.
      expect(playlist.entries[4].groupTitle, 'Docs');
    });

    test('reports malformed lines and keeps parsing', () {
      final skipped = <String>[];
      final text = File('test/fixtures/m3u/mixed.m3u').readAsStringSync();
      final playlist = parseM3u(text, onSkippedLine: skipped.add);

      expect(playlist.entries, hasLength(4));
      expect(skipped, hasLength(3));
      expect(skipped[0], contains('#EXTINF without a URL line'));
      expect(skipped[1], contains('URL without a preceding #EXTINF'));
      expect(skipped[2], contains('#EXTINF without a URL line'));
    });
  });

  group('authenticate', () {
    test('accepts a valid playlist', () async {
      final (source, _) = build('test/fixtures/m3u/live_only.m3u');
      await source.authenticate();
    });

    test('rejects non-playlist content', () async {
      final (source, _) = build('test/fixtures/m3u/not_playlist.txt');
      expect(
        () => source.authenticate(),
        throwsA(isA<SourceException>().having(
            (e) => e.message, 'message', contains('Not a valid M3U playlist'))),
      );
    });

    test('surfaces unreadable file as SourceException', () async {
      final (source, _) = build('test/fixtures/m3u/does_not_exist.m3u');
      expect(() => source.authenticate(), throwsA(isA<SourceException>()));
    });
  });

  group('live mapping', () {
    test('groups become categories in first-appearance order', () async {
      final (source, _) = build('test/fixtures/m3u/live_only.m3u');
      final categories = await source.getLiveCategories();

      expect(categories.map((c) => c.name),
          ['NL | Algemeen', 'Sports', 'Uncategorized', 'Docs']);
      expect(categories.map((c) => c.sortOrder), [0, 1, 2, 3]);
      expect(categories.every((c) => c.type == CategoryType.live), isTrue);
    });

    test('channels map tvg attributes onto the domain model', () async {
      final (source, _) = build('test/fixtures/m3u/live_only.m3u');
      final channels = await source.getLiveStreams();

      expect(channels, hasLength(5));
      final npo = channels[0];
      expect(npo.id, stableId('http://stream.example.com/npo1/index.m3u8'));
      expect(npo.name, 'NPO 1 HD');
      expect(npo.epgChannelId, 'npo1.nl');
      expect(npo.logoUrl, 'http://logo.example.com/npo1.png');
      expect(npo.categoryId, 'NL | Algemeen');
      expect(npo.cachedAt, fixedNow);
    });

    test('category filter works', () async {
      final (source, _) = build('test/fixtures/m3u/live_only.m3u');
      final filtered =
          await source.getLiveStreams(categoryId: 'NL | Algemeen');
      expect(filtered.map((c) => c.name), ['NPO 1 HD', 'RTL 4']);
    });
  });

  group('mixed playlist VOD split', () {
    test('splits live and VOD on URL extension', () async {
      final (source, _) = build('test/fixtures/m3u/mixed.m3u');

      final channels = await source.getLiveStreams();
      expect(channels.map((c) => c.name), ['Channel One', 'Channel Two']);

      final movies = await source.getVodStreams();
      expect(movies.map((m) => m.name), ['Die Hard (1988)', 'The Matrix (1999)']);
      expect(movies[0].containerExt, 'mp4');
      expect(movies[0].year, 1988);
      expect(movies[1].containerExt, 'mkv');
      expect(movies[1].year, 1999);
      expect(movies[1].posterUrl, 'http://logo.example.com/matrix.jpg');

      final vodCategories = await source.getVodCategories();
      expect(vodCategories.single.name, 'Movies | Action');
      expect(vodCategories.single.type, CategoryType.vod);
    });

    test('vod info returns the same model; unknown id throws', () async {
      final (source, _) = build('test/fixtures/m3u/mixed.m3u');
      final movies = await source.getVodStreams();

      final info = await source.getVodInfo(movies.first.id);
      expect(info, movies.first);
      expect(() => source.getVodInfo('nope'), throwsA(isA<SourceException>()));
    });
  });

  group('stream URLs', () {
    test('returns the original playlist URL for a known id', () async {
      final (source, _) = build('test/fixtures/m3u/mixed.m3u');
      final movies = await source.getVodStreams();

      final url = source.buildStreamUrl(StreamRef(
        accountId: 'm3u1',
        type: StreamType.movie,
        streamId: movies.first.id,
        containerExt: movies.first.containerExt,
      ));
      expect(url, 'http://host.example.com/vod/diehard.mp4');
    });

    test('throws before the playlist is loaded', () {
      final (source, _) = build('test/fixtures/m3u/mixed.m3u');
      expect(
        () => source.buildStreamUrl(const StreamRef(
            accountId: 'm3u1', type: StreamType.live, streamId: 'x')),
        throwsA(isA<SourceException>()),
      );
    });
  });

  group('unsupported surfaces degrade gracefully', () {
    test('series lists are empty; series info throws; EPG is empty', () async {
      final (source, _) = build('test/fixtures/m3u/live_only.m3u');
      expect(await source.getSeriesCategories(), isEmpty);
      expect(await source.getSeries(), isEmpty);
      expect(() => source.getSeriesInfo('15'), throwsA(isA<SourceException>()));
      expect(await source.getShortEpg('any'), isEmpty);
    });

    test('explicit EPG url wins over the playlist header url-tvg', () async {
      final (explicit, _) = build('test/fixtures/m3u/live_only.m3u',
          epgUrl: 'http://custom.example.com/epg.xml');
      await explicit.authenticate();
      expect(explicit.effectiveEpgUrl, 'http://custom.example.com/epg.xml');

      final (fromHeader, _) = build('test/fixtures/m3u/live_only.m3u');
      await fromHeader.authenticate();
      expect(fromHeader.effectiveEpgUrl, 'http://epg.example.com/guide.xml');
    });
  });
}
