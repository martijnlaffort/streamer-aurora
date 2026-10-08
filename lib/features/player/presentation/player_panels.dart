import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/matching/title_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/focus_highlight.dart';
import '../../../domain/models/models.dart' show WatchProgress;
import '../player_request.dart';

/// Opens [child] as a panel that slides in from the right over the video, the
/// way Netflix and HBO show episodes and languages: the picture stays visible
/// beside it, BACK or a tap on the picture closes it, and the remote's focus
/// stays inside it while it is open.
Future<T?> showPlayerPanel<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 560,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      final size = MediaQuery.sizeOf(context);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.surface,
          child: SizedBox(
            width: size.width * 0.9 < maxWidth ? size.width * 0.9 : maxWidth,
            height: size.height,
            child: SafeArea(left: false, child: child),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// One choice in the audio or subtitle column.
class TrackOption {
  const TrackOption(this.id, this.label);

  final String id;
  final String label;
}

/// Audio and subtitles side by side, in one panel.
///
/// One button and one place, instead of two look-alike icons opening two
/// separate lists. A choice applies at once and the panel stays open, so both
/// can be set in one visit; LEFT/RIGHT cross between the columns.
///
/// With [onAudioDelay], an Audio sync control sits underneath (DOWN from the
/// bottom of either column), so sound can be lined up with the picture while
/// watching it.
class AudioSubtitlePanel extends StatefulWidget {
  const AudioSubtitlePanel({
    super.key,
    required this.audio,
    required this.subtitles,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.onAudio,
    required this.onSubtitle,
    this.audioDelayMs = 0,
    this.onAudioDelay,
  });

  final List<TrackOption> audio;
  final List<TrackOption> subtitles;
  final String selectedAudio;
  final String selectedSubtitle;
  final ValueChanged<String> onAudio;
  final ValueChanged<String> onSubtitle;

  /// Current Audio sync offset; positive holds the sound back.
  final int audioDelayMs;
  final ValueChanged<int>? onAudioDelay;

  /// 10 ms a press: small enough to settle on what looks right, and the
  /// remote's key repeat covers a long way quickly.
  static const delayStepMs = 10;
  static const delayLimitMs = 300;

  @override
  State<AudioSubtitlePanel> createState() => _AudioSubtitlePanelState();
}

class _AudioSubtitlePanelState extends State<AudioSubtitlePanel> {
  late String _audio = widget.selectedAudio;
  late String _subtitle = widget.selectedSubtitle;

  late int _delay = widget.audioDelayMs;

  late final _audioNodes = [for (final _ in widget.audio) FocusNode()];
  late final _subtitleNodes = [for (final _ in widget.subtitles) FocusNode()];
  final _earlierNode = FocusNode(debugLabel: 'sync-earlier');

  /// The list row the cursor left the columns from, to go back to on UP.
  FocusNode? _leftFrom;

  @override
  void dispose() {
    for (final node in [..._audioNodes, ..._subtitleNodes, _earlierNode]) {
      node.dispose();
    }
    super.dispose();
  }

  void _nudge(int ms) {
    final next = ms.clamp(
        -AudioSubtitlePanel.delayLimitMs, AudioSubtitlePanel.delayLimitMs);
    if (next == _delay) return;
    setState(() => _delay = next);
    widget.onAudioDelay?.call(next);
  }

  /// UP/DOWN stay inside a column. Left to geometry, DOWN off the bottom of
  /// the shorter column jumped sideways into the other one.
  KeyEventResult _stepInColumn(List<FocusNode> nodes, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!down && event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final at = nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (at == -1) return KeyEventResult.ignored;
    final next = at + (down ? 1 : -1);
    if (next >= 0 && next < nodes.length) {
      nodes[next].requestFocus();
    } else if (down && widget.onAudioDelay != null) {
      _leftFrom = nodes[at];
      _earlierNode.requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// UP from the sync row goes back to the row it was entered from.
  KeyEventResult _onSyncKey(FocusNode node, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      (_leftFrom ?? _audioNodes.firstOrNull)?.requestFocus();
      return KeyEventResult.handled;
    }
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _syncRow() {
    final step = AudioSubtitlePanel.delayStepMs;
    final limit = AudioSubtitlePanel.delayLimitMs;
    final value = _delay == 0
        ? '0 ms'
        : '${_delay > 0 ? '+' : '−'}${_delay.abs()} ms';
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onSyncKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Audio sync', style: AppTypography.body),
                  const SizedBox(height: 2),
                  Text(
                    'Voices before the lips move: press +. '
                    'After: press −. Kept for this screen.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FocusHighlight(
              borderRadius: 24,
              child: IconButton.filledTonal(
                focusNode: _earlierNode,
                tooltip: 'Sound earlier',
                onPressed: _delay > -limit ? () => _nudge(_delay - step) : null,
                icon: const Icon(Icons.remove),
              ),
            ),
            SizedBox(
              width: 88,
              child: Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            FocusHighlight(
              borderRadius: 24,
              child: IconButton.filledTonal(
                tooltip: 'Sound later',
                onPressed: _delay < limit ? () => _nudge(_delay + step) : null,
                icon: const Icon(Icons.add),
              ),
            ),
            const SizedBox(width: 8),
            FocusHighlight(
              borderRadius: 20,
              child: TextButton(
                // Always there, just disabled at zero, so the buttons beside
                // it never move under the cursor.
                onPressed: _delay == 0 ? null : () => _nudge(0),
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The cursor starts on the current audio track; failing that (nothing
    // selected that is listed), on the first entry.
    final audioFocus = widget.audio.any((o) => o.id == _audio)
        ? _audio
        : widget.audio.firstOrNull?.id;
    final columns = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _column(
              title: 'Audio',
              options: widget.audio,
              nodes: _audioNodes,
              selected: _audio,
              autofocusId: audioFocus,
              empty: 'Only one audio track',
              onPick: (id) {
                setState(() => _audio = id);
                widget.onAudio(id);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _column(
              title: 'Subtitles',
              options: widget.subtitles,
              nodes: _subtitleNodes,
              selected: _subtitle,
              autofocusId: null,
              empty: 'No subtitles in this stream',
              onPick: (id) {
                setState(() => _subtitle = id);
                widget.onSubtitle(id);
              },
            ),
          ),
        ],
      ),
    );
    if (widget.onAudioDelay == null) return columns;
    return Column(
      children: [
        Expanded(child: columns),
        const Divider(height: 1),
        _syncRow(),
      ],
    );
  }

  Widget _column({
    required String title,
    required List<TrackOption> options,
    required List<FocusNode> nodes,
    required String selected,
    required String? autofocusId,
    required String empty,
    required ValueChanged<String> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text(title, style: AppTypography.title),
        ),
        Expanded(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) => _stepInColumn(nodes, event),
            child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (options.length <= 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(empty,
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              for (final (i, option) in options.indexed)
                FocusHighlight(
                  scale: 1.0,
                  ensureVisible: true,
                  child: ListTile(
                    focusNode: nodes[i],
                    autofocus: option.id == autofocusId,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      option.id == selected ? Icons.check : null,
                      color: AppColors.accent,
                    ),
                    minLeadingWidth: 24,
                    title: Text(
                      option.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: option.id == selected
                          ? const TextStyle(fontWeight: FontWeight.w700)
                          : null,
                    ),
                    onTap: () => onPick(option.id),
                  ),
                ),
            ],
          ),
          ),
        ),
      ],
    );
  }
}

/// The series' episodes, from inside the player: season tabs on top, the
/// season's episodes below, the cursor on the one that is playing.
///
/// Pops with the queue index of the episode picked, or null.
class EpisodesPanel extends StatefulWidget {
  const EpisodesPanel({
    super.key,
    required this.queue,
    required this.currentIndex,
    required this.loadProgress,
  });

  final List<PlayerItem> queue;
  final int currentIndex;

  /// Watch progress for the given content keys — fetched per season as it is
  /// shown, rather than for every episode of a long-running show up front.
  final Future<Map<String, WatchProgress>> Function(List<String> keys)
      loadProgress;

  @override
  State<EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends State<EpisodesPanel> {
  late final List<int> _seasons = [
    for (final s in {for (final item in widget.queue) item.season ?? 0}) s,
  ]..sort();

  late int _season = widget.queue[widget.currentIndex].season ?? 0;

  Map<String, WatchProgress> _progress = const {};
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Queue indexes of the selected season, in queue order.
  List<int> get _episodes => [
        for (var i = 0; i < widget.queue.length; i++)
          if ((widget.queue[i].season ?? 0) == _season) i,
      ];

  Future<void> _load() async {
    final ticket = ++_loads;
    final keys = [for (final i in _episodes) widget.queue[i].contentKey];
    final progress = await widget.loadProgress(keys);
    // A slower answer for a season that is no longer shown must not land.
    if (mounted && ticket == _loads) setState(() => _progress = progress);
  }

  void _pickSeason(int season) {
    if (season == _season) return;
    setState(() => _season = season);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.queue[widget.currentIndex];
    final episodes = _episodes;
    // On the playing episode when it is in this season, otherwise the first.
    final focusIndex = episodes.contains(widget.currentIndex)
        ? widget.currentIndex
        : episodes.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
          child: Text(current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text('Episodes',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        if (_seasons.length > 1)
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(44),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _seasons.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final season = _seasons[i];
                // Moving the cursor onto a season shows it — no extra OK
                // needed to see what is in it. The rows that appear do not
                // take the cursor (autofocus never steals it from the tab),
                // so LEFT/RIGHT keep walking the seasons and DOWN goes in.
                return Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (focused) {
                    if (focused) _pickSeason(season);
                  },
                  child: FocusHighlight(
                    borderRadius: 20,
                    scale: 1.0,
                    ensureVisible: true,
                    child: ChoiceChip(
                      label:
                          Text(season == 0 ? 'Specials' : 'Season $season'),
                      selected: season == _season,
                      showCheckmark: false,
                      selectedColor: AppColors.accent.withValues(alpha: 0.28),
                      onSelected: (_) => _pickSeason(season),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            // A new list per season, so the cursor lands on the new rows.
            key: ValueKey(_season),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final i in episodes)
                _EpisodeRow(
                  item: widget.queue[i],
                  playing: i == widget.currentIndex,
                  autofocus: i == focusIndex,
                  progress: _progress[widget.queue[i].contentKey],
                  onTap: () => Navigator.of(context).pop(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.item,
    required this.playing,
    required this.autofocus,
    required this.progress,
    required this.onTap,
  });

  final PlayerItem item;
  final bool playing;
  final bool autofocus;
  final WatchProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final completed = p?.completed ?? false;
    final fraction = p != null && p.durationSeconds > 0
        ? (p.positionSeconds / p.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    final name = prettyEpisodeTitle(item.episodeTitle ?? '',
        seriesName: item.title);
    final number = item.episode;
    final heading = switch ((number, name)) {
      (null, '') => item.subtitle ?? item.title,
      (null, final n) => n,
      (final e?, '') => 'Episode $e',
      (final e?, final n) => '$e. $n',
    };
    final minutes = item.durationSeconds == null
        ? null
        : (item.durationSeconds! / 60).ceil();
    final image = item.imageUrl;
    final detail = [
      if (playing) 'Now playing',
      if (minutes != null) '$minutes min',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: FocusHighlight(
        scale: 1.0,
        ensureVisible: true,
        child: ListTile(
          autofocus: autofocus,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onTap: onTap,
          leading: SizedBox(
            width: 112,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        memCacheWidth: 360,
                        placeholder: (context, url) =>
                            ColoredBox(color: AppColors.surfaceElevated),
                        errorWidget: (context, url, error) =>
                            ColoredBox(color: AppColors.surfaceElevated),
                      )
                    else
                      ColoredBox(color: AppColors.surfaceElevated),
                    if (playing)
                      const ColoredBox(
                        color: Colors.black45,
                        child: Center(
                          child: Icon(Icons.equalizer_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    if (fraction > 0 && !completed)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 3,
                          backgroundColor: Colors.black38,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          title: Text(heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: playing
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null),
          subtitle: detail.isEmpty
              ? null
              : Text(
                  detail,
                  style: TextStyle(
                      color: playing
                          ? AppColors.accentAlt
                          : AppColors.textSecondary),
                ),
          trailing: completed
              ? Icon(Icons.check_circle, color: AppColors.accentAlt, size: 20)
              : null,
        ),
      ),
    );
  }
}
