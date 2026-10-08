import 'package:dawnplayer/core/theme/app_theme.dart';
import 'package:dawnplayer/domain/models/models.dart';
import 'package:dawnplayer/features/player/player_request.dart';
import 'package:dawnplayer/features/player/presentation/player_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerItem _episode(int season, int episode) => PlayerItem(
      streamRef: StreamRef(
          accountId: 'a', type: StreamType.episode, streamId: 's${season}e$episode'),
      title: 'The Show',
      contentKey: 'a:episode:s${season}e$episode',
      season: season,
      episode: episode,
      episodeTitle: 'Chapter $season.$episode',
      durationSeconds: 45 * 60,
    );

/// Opens [panel] the way the player does and returns what it popped with.
Future<Object?> _open(WidgetTester tester, Widget panel,
    {required List<Object?> popped}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 720));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async =>
                popped.add(await showPlayerPanel<Object>(context, child: panel)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return null;
}

String? _focusedText(WidgetTester tester) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final texts = find.descendant(
      of: find.byWidget(context.widget), matching: find.byType(Text));
  return texts.evaluate().map((e) => (e.widget as Text).data).join(' | ');
}

void main() {
  final queue = [
    for (var e = 1; e <= 3; e++) _episode(1, e),
    for (var e = 1; e <= 4; e++) _episode(2, e),
  ];

  testWidgets('episodes: opens on the playing episode, OK plays the one picked',
      (tester) async {
    final popped = <Object?>[];
    await _open(
      tester,
      EpisodesPanel(
        queue: queue,
        currentIndex: 4, // S2 E2
        loadProgress: (keys) async => {
          'a:episode:s2e1': WatchProgress(
            contentKey: 'a:episode:s2e1',
            positionSeconds: 2700,
            durationSeconds: 2700,
            updatedAt: DateTime.utc(2026),
            completed: true,
          ),
        },
      ),
      popped: popped,
    );

    // Season 2 is shown, with the cursor on the episode that is playing.
    expect(find.text('3. Chapter 2.3'), findsOneWidget);
    expect(find.text('1. Chapter 1.1'), findsNothing);
    expect(_focusedText(tester), contains('2. Chapter 2.2'));
    expect(find.textContaining('Now playing'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), contains('3. Chapter 2.3'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(popped, [5]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episodes: moving onto a season tab shows that season',
      (tester) async {
    final popped = <Object?>[];
    await _open(
      tester,
      EpisodesPanel(
        queue: queue,
        currentIndex: 4,
        loadProgress: (keys) async => const {},
      ),
      popped: popped,
    );

    // Up from the first row of season 2 reaches the tabs; left is season 1.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(_focusedText(tester), contains('Season 1'));
    expect(find.text('1. Chapter 1.1'), findsOneWidget);
    expect(find.text('3. Chapter 2.3'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(popped, [0]);
  });

  testWidgets('audio & subtitles: a pick applies at once and the panel stays',
      (tester) async {
    final audio = <String>[];
    final subtitles = <String>[];
    final popped = <Object?>[];
    await _open(
      tester,
      AudioSubtitlePanel(
        audio: const [
          TrackOption('auto', 'Auto'),
          TrackOption('1', 'eng'),
          TrackOption('2', 'nld'),
        ],
        subtitles: const [
          TrackOption('no', 'Off'),
          TrackOption('3', 'eng'),
        ],
        selectedAudio: '1',
        selectedSubtitle: 'no',
        onAudio: audio.add,
        onSubtitle: subtitles.add,
      ),
      popped: popped,
    );

    // The cursor starts on the current audio track.
    expect(_focusedText(tester), 'eng');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(audio, ['2']);

    // Across to the subtitles column (onto its last row, the nearest one).
    // DOWN past its end stays in the column instead of jumping back across.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), 'eng');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), 'Off');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(subtitles, ['3']);

    // Still open: both were set in one visit.
    expect(find.text('Subtitles'), findsOneWidget);
    expect(popped, isEmpty);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });
}
