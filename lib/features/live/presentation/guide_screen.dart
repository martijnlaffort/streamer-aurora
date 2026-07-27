import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (e.description != null) ...[
                const SizedBox(height: 12),
                Text(e.description!, style: AppTypography.body),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _playChannel(channel, nowTitle: e.title);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text('Watch ${channel.name}'),
              ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('TV Guide')),
      body: guide.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (data) {
          if (data == null || data.channels.isEmpty) {
            return const Center(
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
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.surface),
                                  right: BorderSide(color: AppColors.surface),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(c.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label),
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
                                      data.programmes[c.epgChannelId ?? c.id] ??
                                          const [];
                                  return _ChannelRow(
                                    programmes: progs,
                                    windowStart: data.windowStart,
                                    windowEnd: data.windowEnd,
                                    pxPerMin: _pxPerMin,
                                    rowHeight: _rowHeight,
                                    onTap: (e) => _showProgramme(e, c),
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
  });

  final List<EpgEntry> programmes;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pxPerMin;
  final double rowHeight;
  final void Function(EpgEntry) onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final blocks = <Widget>[];
    for (final e in programmes) {
      final startClamped = e.start.isBefore(windowStart) ? windowStart : e.start;
      final stopClamped = e.stop.isAfter(windowEnd) ? windowEnd : e.stop;
      final left = startClamped.difference(windowStart).inMinutes * pxPerMin;
      final width =
          stopClamped.difference(startClamped).inMinutes * pxPerMin;
      if (width <= 0) continue;
      final isNow = !now.isBefore(e.start) && now.isBefore(e.stop);
      blocks.add(Positioned(
        left: left,
        width: width,
        top: 4,
        bottom: 4,
        child: GestureDetector(
          onTap: () => onTap(e),
          child: Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isNow ? AppColors.accent.withValues(alpha: 0.28) : AppColors.surface,
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
      ));
    }
    return SizedBox(
      height: rowHeight,
      child: Stack(children: blocks),
    );
  }
}
