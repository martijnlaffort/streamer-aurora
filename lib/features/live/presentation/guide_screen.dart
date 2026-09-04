import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/notifications/reminder_service.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../player/player_request.dart';
import '../live_providers.dart';

/// EPG time-grid guide (PRD §8.5): channels down the side, time across the
/// top, programme blocks in between, with a "now" line. Sticky channel column
/// and time header; the grid scrolls in both axes.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  static const double _pxPerMin = 5;
  static const double _rowHeight = 64;
  static const double _channelColWidth = 128;
  static const double _headerHeight = 36;

  final _hGroup = LinkedScrollControllerGroup();
  final _vGroup = LinkedScrollControllerGroup();
  late final ScrollController _headerH = _hGroup.addAndGet();
  late final ScrollController _bodyH = _hGroup.addAndGet();
  late final ScrollController _channelsV = _vGroup.addAndGet();
  late final ScrollController _rowsV = _vGroup.addAndGet();

  bool _jumpedToNow = false;

  @override
  void dispose() {
    _headerH.dispose();
    _bodyH.dispose();
    _channelsV.dispose();
    _rowsV.dispose();
    super.dispose();
  }

  double _x(DateTime t, DateTime windowStart) =>
      t.difference(windowStart).inMinutes * _pxPerMin;

  void _playChannel(Channel channel, {String? nowTitle}) {
    context.push(
      '/player',
      extra: PlayerRequest(queue: [
        PlayerItem(
          streamRef: StreamRef(
            accountId: channel.accountId,
            type: StreamType.live,
            streamId: channel.id,
          ),
          title: channel.name,
          subtitle: nowTitle != null ? 'Now: $nowTitle' : null,
          contentKey: contentKeyFor(
              accountId: channel.accountId,
              type: StreamType.live,
              id: channel.id),
          isLive: true,
        ),
      ]),
    );
  }

  /// Whether the panel can still serve this programme from its recording.
  ///
  /// Three conditions, all necessary: the channel is recorded at all, the
  /// programme has actually started (there is nothing to catch up on for
  /// something still to air), and it has not fallen out of the archive window.
  bool _canCatchUp(EpgEntry e, Channel channel) {
    if (!channel.hasArchive) return false;
    final now = DateTime.now().toUtc();
    if (!e.start.isBefore(now)) return false;
    final horizon = channel.archiveHorizon(now);
    return horizon != null && e.start.isAfter(horizon);
  }

  /// Plays a past programme from the channel's recording, from its start.
  ///
  /// Unlike live, this has a real beginning and end, so it is handed to the
  /// player as a normal seekable item rather than a live stream.
  void _playCatchUp(EpgEntry e, Channel channel) {
    final minutes = e.stop.difference(e.start).inMinutes;
    context.push(
      '/player',
      extra: PlayerRequest(queue: [
        PlayerItem(
          streamRef: StreamRef(
            accountId: channel.accountId,
            type: StreamType.live,
            streamId: channel.id,
            catchupStart: e.start,
            // A couple of minutes of headroom: panel clocks and EPG listings
            // rarely agree to the second, and overrunning is harmless while
            // stopping short cuts the ending off.
            catchupMinutes: (minutes > 0 ? minutes : 60) + 2,
          ),
          title: e.title,
          subtitle: '${channel.name} · ${_hhmm(e.start)}',
          contentKey: contentKeyFor(
              accountId: channel.accountId,
              type: StreamType.live,
              id: '${channel.id}@${e.start.millisecondsSinceEpoch}'),
          isLive: false,
        ),
      ]),
    );
  }

  /// What OK on a grid cell does, decided by where the cell sits in time.
  ///
  /// The semantics the whole category has converged on, and what people arrive
  /// expecting: a past cell plays it back, the current cell tunes the channel,
  /// a future cell sets a reminder. Everything else stays one hold away, so the
  /// common case is one press rather than a press and a menu.
  Future<void> _activateCell(EpgEntry e, Channel channel) async {
    final now = DateTime.now().toUtc();
    if (!now.isBefore(e.start) && now.isBefore(e.stop)) {
      _playChannel(channel, nowTitle: e.title);
      return;
    }
    if (e.stop.isBefore(now)) {
      if (_canCatchUp(e, channel)) {
        _playCatchUp(e, channel);
      } else {
        // Say why rather than doing nothing: "already finished" is information,
        // an unresponsive cell is a bug report.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(channel.hasArchive
                ? 'That is older than this channel\'s catch-up window.'
                : 'This channel has no catch-up.')));
      }
      return;
    }
    if (!ReminderService.isSupported) {
      _showProgramme(e, channel);
      return;
    }
    await _toggleReminder(e, channel);
  }

  /// Sets or clears a reminder for a future cell, and says which it did.
  Future<void> _toggleReminder(EpgEntry e, Channel channel) async {
    final id = Reminder.idFor(
        accountId: channel.accountId,
        channelId: channel.id,
        startsAt: e.start);
    final repo = ref.read(remindersRepositoryProvider);
    final service = ref.read(reminderServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final reminder = Reminder(
      id: id,
      accountId: channel.accountId,
      channelId: channel.id,
      channelName: channel.displayName,
      title: e.title,
      startsAt: e.start,
      notificationId: Reminder.notificationIdFor(id),
    );

    if (await repo.exists(id)) {
      await service.cancel(reminder);
      await repo.remove(id);
      ref.invalidate(upcomingRemindersProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Reminder removed.')));
      return;
    }
    if (!await service.requestPermission()) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Allow notifications to be reminded.')));
      return;
    }
    if (!await service.schedule(reminder)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('That programme starts too soon.')));
      return;
    }
    await repo.save(reminder);
    ref.invalidate(upcomingRemindersProvider);
    messenger.showSnackBar(SnackBar(
        content: Text('Reminder set for ${e.title}.')));
  }

  void _showProgramme(EpgEntry e, Channel channel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title, style: AppTypography.title),
              const SizedBox(height: 4),
              Text(
                '${_hhmm(e.start)} – ${_hhmm(e.stop)}  ·  ${channel.name}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (e.description != null) ...[
                const SizedBox(height: 12),
                Text(e.description!, style: AppTypography.body),
              ],
              const SizedBox(height: 16),
              if (_canCatchUp(e, channel))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _playCatchUp(e, channel);
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Watch from the start'),
                  ),
                ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _playChannel(channel, nowTitle: e.title);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text('Watch ${channel.name} live'),
              ),
              // Only for programmes that have not started: a reminder for
              // something already on air is just a worse Play button.
              if (ReminderService.isSupported &&
                  e.start.isAfter(DateTime.now().toUtc()))
                _ReminderButton(entry: e, channel: channel),
            ],
          ),
        ),
      ),
    );
  }

  String _hhmm(DateTime utc) {
    final l = utc.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(guideProvider);

    final coverage = ref.watch(guideCoverageProvider).value;
    final unmatched =
        coverage == null ? 0 : coverage.total - coverage.covered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Guide'),
        actions: [
          // Silent degradation is what earns the one-star review: without this
          // a guide missing a thousand channels looks exactly like a guide that
          // works. Says the number, and routes to the fix.
          if (unmatched > 0)
            TextButton.icon(
              icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
              label: Text('$unmatched without guide'),
              onPressed: () => context.push('/guide/coverage'),
            ),
        ],
        // Say so when the grid is bounded, rather than quietly omitting rows.
        bottom: (guide.value?.truncated ?? false)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(
                    'Showing the first $guideChannelLimit channels with a guide',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              )
            : null,
      ),
      body: guide.when(
        // A background sync must never blank a screen that already has content:
        // when() shows its loading branch on a dependency reload by default.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(guideProvider)),
        data: (data) {
          if (data == null || data.channels.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text('No programme guide available.',
                        textAlign: TextAlign.center),
                    SizedBox(height: 4),
                    Text(
                      'Xtream panels expose one automatically; for M3U, add an '
                      'XMLTV EPG URL when editing the account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final totalMin =
              data.windowEnd.difference(data.windowStart).inMinutes;
          final totalWidth = totalMin * _pxPerMin;
          final nowX = _x(DateTime.now().toUtc(), data.windowStart)
              .clamp(0.0, totalWidth);

          // Land on "now" the first time the grid is shown.
          if (!_jumpedToNow) {
            _jumpedToNow = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_bodyH.hasClients) {
                _bodyH.jumpTo((nowX - 80).clamp(0.0, _bodyH.position.maxScrollExtent));
              }
            });
          }

          return Column(
            children: [
              // Time header row.
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    const SizedBox(width: _channelColWidth),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _headerH,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: totalWidth,
                          child: _TimeAxis(
                            windowStart: data.windowStart,
                            totalMin: totalMin,
                            pxPerMin: _pxPerMin,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    // Sticky channel column.
                    SizedBox(
                      width: _channelColWidth,
                      child: ListView.builder(
                        controller: _channelsV,
                        physics: const ClampingScrollPhysics(),
                        itemCount: data.channels.length,
                        itemBuilder: (context, i) {
                          final c = data.channels[i];
                          return InkWell(
                            onTap: () => _playChannel(c),
                            child: Container(
                              height: _rowHeight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.surface),
                                  right: BorderSide(color: AppColors.surface),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(c.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.label),
                                  // How far back this channel can be replayed,
                                  // stated on the row so the edge of catch-up
                                  // is legible before someone walks into it.
                                  if (c.hasArchive)
                                    Text(
                                      '↺ ${c.archiveDays ?? 2}d',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Scrollable programme grid + now line.
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _bodyH,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalWidth,
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _rowsV,
                                physics: const ClampingScrollPhysics(),
                                itemCount: data.channels.length,
                                itemBuilder: (context, i) {
                                  final c = data.channels[i];
                                  final progs =
                                      data.programmes[data.epgIds[c.id] ??
                                              c.epgChannelId ??
                                              c.id] ??
                                          const [];
                                  return _ChannelRow(
                                    programmes: progs,
                                    windowStart: data.windowStart,
                                    windowEnd: data.windowEnd,
                                    pxPerMin: _pxPerMin,
                                    rowHeight: _rowHeight,
                                    onTap: (e) => _activateCell(e, c),
                                    onLongPress: (e) => _showProgramme(e, c),
                                    hasArchive: c.hasArchive,
                                  );
                                },
                              ),
                              // Now line.
                              Positioned(
                                left: nowX,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                    width: 2, color: AppColors.accentAlt),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sets or cancels a reminder for one programme.
///
/// A toggle rather than a fire-and-forget button: the guide is the only place
/// this can be undone from, so a button that could only ever add would leave
/// the user with no way to take it back.
class _ReminderButton extends ConsumerWidget {
  const _ReminderButton({required this.entry, required this.channel});

  final EpgEntry entry;
  final Channel channel;

  String get _id => Reminder.idFor(
        accountId: channel.accountId,
        channelId: channel.id,
        startsAt: entry.start,
      );

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool exists) async {
    final repo = ref.read(remindersRepositoryProvider);
    final service = ref.read(reminderServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (exists) {
      final reminder = _build();
      await service.cancel(reminder);
      await repo.remove(_id);
      ref.invalidate(upcomingRemindersProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Reminder removed.')));
      return;
    }

    // Asked for here, where the prompt has a reason attached, rather than at
    // launch where it gets refused by reflex.
    if (!await service.requestPermission()) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Allow notifications to be reminded.')));
      return;
    }
    final reminder = _build();
    if (!await service.schedule(reminder)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('That programme starts too soon.')));
      return;
    }
    await repo.save(reminder);
    ref.invalidate(upcomingRemindersProvider);
    messenger.showSnackBar(SnackBar(
        content: Text('Reminder set for ${reminder.leadMinutes} minutes '
            'before it starts.')));
  }

  Reminder _build() => Reminder(
        id: _id,
        accountId: channel.accountId,
        channelId: channel.id,
        channelName: channel.displayName,
        title: entry.title,
        startsAt: entry.start,
        notificationId: Reminder.notificationIdFor(_id),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exists = ref.watch(hasReminderProvider(_id)).value ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _toggle(context, ref, exists),
        icon: Icon(exists
            ? Icons.notifications_active
            : Icons.notifications_none_outlined),
        label: Text(exists ? 'Cancel reminder' : 'Remind me'),
      ),
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.windowStart,
    required this.totalMin,
    required this.pxPerMin,
  });

  final DateTime windowStart;
  final int totalMin;
  final double pxPerMin;

  @override
  Widget build(BuildContext context) {
    // A tick every 30 minutes.
    final ticks = <Widget>[];
    for (var m = 0; m <= totalMin; m += 30) {
      final t = windowStart.add(Duration(minutes: m)).toLocal();
      ticks.add(Positioned(
        left: m * pxPerMin,
        top: 8,
        child: Text(
          '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ));
    }
    return Stack(children: ticks);
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.programmes,
    required this.windowStart,
    required this.windowEnd,
    required this.pxPerMin,
    required this.rowHeight,
    required this.onTap,
    required this.onLongPress,
    required this.hasArchive,
  });

  final List<EpgEntry> programmes;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pxPerMin;
  final double rowHeight;
  final void Function(EpgEntry) onTap;
  final void Function(EpgEntry) onLongPress;

  /// Whether the panel keeps a recording of this channel. Decides whether a
  /// past cell is playable or merely history.
  final bool hasArchive;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final blocks = <Widget>[];

    // Fill the gaps first, so the row is continuous. An empty stretch of grid
    // looks like the app failed to draw something; a labelled "No information"
    // block says what is actually true — the provider's guide stops here.
    var cursor = windowStart;
    final sorted = [...programmes]..sort((a, b) => a.start.compareTo(b.start));
    for (final e in [...sorted, null]) {
      final gapEnd = e == null
          ? windowEnd
          : (e.start.isAfter(windowEnd) ? windowEnd : e.start);
      if (gapEnd.isAfter(cursor)) {
        final left = cursor.difference(windowStart).inMinutes * pxPerMin;
        final width = gapEnd.difference(cursor).inMinutes * pxPerMin;
        // Below a few minutes it is listing noise, not a gap worth naming.
        if (width > 8) {
          blocks.add(Positioned(
            left: left,
            width: width,
            top: 4,
            bottom: 4,
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surface),
              ),
              alignment: Alignment.centerLeft,
              child: Text('No information',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ));
        }
      }
      if (e == null) break;
      if (e.stop.isAfter(cursor)) cursor = e.stop;
    }

    for (final e in programmes) {
      final startClamped = e.start.isBefore(windowStart) ? windowStart : e.start;
      final stopClamped = e.stop.isAfter(windowEnd) ? windowEnd : e.stop;
      final left = startClamped.difference(windowStart).inMinutes * pxPerMin;
      final width =
          stopClamped.difference(startClamped).inMinutes * pxPerMin;
      if (width <= 0) continue;
      final isNow = !now.isBefore(e.start) && now.isBefore(e.stop);
      final isPast = e.stop.isBefore(now);
      // A past cell on a channel the panel does not record is history, not a
      // thing you can play. Dimmed so the boundary is legible BEFORE you press
      // it — a cell that looks identical and then does nothing reads as broken.
      final dead = isPast && !hasArchive;
      blocks.add(Positioned(
        left: left,
        width: width,
        top: 4,
        bottom: 4,
        // InkWell so a D-pad OK press activates the block; GestureDetector
        // takes focus on a TV and then ignores it.
        child: InkWell(
          onTap: () => onTap(e),
          // Hold for the full sheet, the convention the whole category shares:
          // OK does the obvious thing, hold opens everything else.
          onLongPress: () => onLongPress(e),
          borderRadius: BorderRadius.circular(6),
          child: Opacity(
            opacity: dead ? 0.45 : 1,
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isNow
                    ? AppColors.accent.withValues(alpha: 0.28)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isNow ? AppColors.accent : AppColors.surfaceElevated),
              ),
              alignment: Alignment.centerLeft,
              child: Text(e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label),
            ),
          ),
        ),
      ));
    }
    return SizedBox(
      height: rowHeight,
      child: Stack(children: blocks),
    );
  }
}
