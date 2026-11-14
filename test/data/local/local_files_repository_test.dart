import 'dart:io';

import 'package:dawnplayer/data/local/local_files_repository.dart';
import 'package:dawnplayer/data/local/local_media_platform.dart';
import 'package:dawnplayer/data/local/playlist_files.dart';
import 'package:dawnplayer/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DateTime now;

  LocalFilesRepository repo() => LocalFilesRepository(
        directory: () async => dir,
        clock: () => now,
      );

  LocalMediaPick pick(String name, {int size = 1000, String? ref}) =>
      LocalMediaPick(
        ref: ref ?? 'bookmark-$name',
        name: name,
        path: '/files/$name',
        sizeBytes: size,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dawn_local_files_');
    now = DateTime.utc(2026, 11, 14, 20);
  });

  tearDown(() => dir.delete(recursive: true));

  test('a file is identified by name and size, not by path or bookmark', () {
    final a = localFileId(name: 'Holiday.mkv', sizeBytes: 42);
    expect(localFileId(name: 'Holiday.mkv', sizeBytes: 42), a);
    expect(localFileId(name: 'Holiday.mkv', sizeBytes: 43), isNot(a));
    expect(localFileId(name: 'Other.mkv', sizeBytes: 42), isNot(a));
  });

  test('recorded files survive a restart, most recent first', () async {
    await repo().recordOpened(pick('First.mp4'));
    now = now.add(const Duration(minutes: 5));
    await repo().recordOpened(pick('Second.mkv'));

    // A fresh repository reads only what is on disk.
    final files = await repo().all();
    expect(files.map((f) => f.name), ['Second.mkv', 'First.mp4']);
    expect(files.first.title, 'Second');
    expect(files.first.extension, 'mkv');
  });

  test('opening the same file again refreshes it instead of duplicating',
      () async {
    final r = repo();
    final first = await r.recordOpened(pick('Film.mkv', ref: 'old'));
    await r.setSubtitle(first.id, path: '/subs/film.srt', name: 'film.srt');
    now = now.add(const Duration(days: 1));
    final again = await r.recordOpened(pick('Film.mkv', ref: 'new'));

    expect(again.id, first.id);
    final files = await repo().all();
    expect(files, hasLength(1));
    expect(files.single.ref, 'new');
    expect(files.single.openedAt, now);
    // The attached subtitle is kept across re-opens.
    expect(files.single.subtitlePath, '/subs/film.srt');
  });

  test('a local file is keyed like a film under the local account', () async {
    final file = await repo().recordOpened(pick('Film.mkv'));
    expect(isLocalStream(file.streamRef), isTrue);
    expect(file.streamRef.type, StreamType.movie);
    final key = parseContentKey(file.contentKey)!;
    expect(key.accountId, kLocalAccountId);
    expect(key.id, file.id);
  });

  test('clearing a subtitle and removing a file persist', () async {
    final r = repo();
    final a = await r.recordOpened(pick('A.mp4'));
    final b = await r.recordOpened(pick('B.mp4'));
    await r.setSubtitle(a.id, path: '/subs/a.srt', name: 'a.srt');
    await r.setSubtitle(a.id);
    await r.remove(b.id);

    final files = await repo().all();
    expect(files.map((f) => f.id), [a.id]);
    expect(files.single.subtitlePath, isNull);
  });

  test('the list is capped', () async {
    final r = repo();
    for (var i = 0; i < LocalFilesRepository.maxEntries + 5; i++) {
      now = now.add(const Duration(seconds: 1));
      await r.recordOpened(pick('File $i.mp4'));
    }
    final files = await repo().all();
    expect(files, hasLength(LocalFilesRepository.maxEntries));
    expect(files.first.name, 'File ${LocalFilesRepository.maxEntries + 4}.mp4');
  });

  test('a corrupt list file starts empty rather than failing', () async {
    await File('${dir.path}/local_files.json').writeAsString('{not json');
    expect(await repo().all(), isEmpty);
  });

  group('playlist files', () {
    test('are copied in and addressed relative to app storage', () async {
      final source = File('${dir.path}/picked.m3u')
        ..writeAsStringSync('#EXTM3U\n');
      final location = await importPlaylistFile(
        LocalMediaPick(
          ref: 'path:${source.path}',
          name: 'My list.m3u',
          path: source.path,
          sizeBytes: 8,
        ),
        base: () async => dir,
      );

      expect(isAppFile(location), isTrue);
      expect(location, isNot(contains(dir.path)));
      expect(playlistDisplayName(location), 'My list.m3u');
      final copy = await appFileFor(location, base: () async => dir);
      expect(await copy.readAsString(), '#EXTM3U\n');
    });

    test('a link is shown as itself', () {
      expect(playlistDisplayName('https://example.com/a.m3u'),
          'https://example.com/a.m3u');
    });
  });
}
