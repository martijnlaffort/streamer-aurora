import 'package:dawnplayer/core/theme/app_theme.dart';
import 'package:dawnplayer/features/live/live_providers.dart';
import 'package:dawnplayer/features/live/presentation/guide_screen.dart';
import 'package:dawnplayer/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guide grid renders channels and programmes without overflowing',
      (tester) async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day, now.hour);
    final channel = Channel(
      id: 'ch1',
      accountId: 'acc1',
      categoryId: 'c',
      name: 'Test One',
      epgChannelId: 'one.epg',
      cachedAt: now,
    );
    final data = GuideData(
      channels: [channel],
      programmes: {
        'one.epg': [
          EpgEntry(
              channelId: 'one.epg',
              start: start,
              stop: start.add(const Duration(hours: 1)),
              title: 'Morning Show'),
          EpgEntry(
              channelId: 'one.epg',
              start: start.add(const Duration(hours: 1)),
              stop: start.add(const Duration(hours: 2)),
              title: 'Noon News'),
        ],
      },
      windowStart: start,
      windowEnd: start.add(const Duration(hours: 12)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideProvider.overrideWith((ref) async => data),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const GuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test One'), findsOneWidget);
    expect(find.text('Morning Show'), findsOneWidget);
    expect(find.text('Noon News'), findsOneWidget);
    // No render overflow / exceptions during layout.
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide shows an empty state when there is no EPG', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const GuideScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No programme guide'), findsOneWidget);
  });
}
