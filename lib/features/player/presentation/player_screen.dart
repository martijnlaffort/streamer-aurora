import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/watch_progress_repository.dart';
import '../../../domain/models/models.dart' show Preferences;
import '../player_request.dart';

/// Android emulators stall on hardware video decode (documented media_kit
/// quirk): run with `--dart-define=AURORA_SW_DECODE=true` there. Real
/// devices keep hardware decoding.
const bool _forceSoftwareDecode = bool.fromEnvironment('AURORA_SW_DECODE');

/// The player (PRD §8.8): media_kit playback with a custom HBO-style
/// controls overlay, audio/subtitle selection, gestures, and an
/// autoplay-next queue.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.request});

  final PlayerRequest request;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Grabbed once so dispose-time saving never touches `ref` late.
  late final WatchProgressRepository _progressRepo =
      ref.read(watchProgressRepositoryProvider);

  late int _index = widget.request.startIndex;

  // Resume state (PRD §8.9).
  int? _pendingResumeSeconds;
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);

  // Language preference state (PRD §8.10).
  Preferences _prefs = const Preferences.defaults();
  bool _autoTracksApplied = false;

  // Live now-playing programme (PRD §8.5), refreshed while watching.
  String? _liveNow;
  Timer? _liveEpgTimer;

  // Playback state mirrored for the overlay.
  bool _playing = false;
  bool _buffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  Tracks _tracks = const Tracks();
  Track _selected = const Track();
  String? _error;

  // Overlay state.
  bool _controlsVisible = true;
  bool _locked = false;
  Timer? _hideTimer;
  String? _gestureHint;
  Timer? _hintTimer;
  double? _dragSeekSeconds;

  // Gestures.
  double _volume = 100;
  double? _brightness;

  // Up next (autoplay).
  Timer? _upNextTimer;
  int? _upNextCountdown;

  PlayerItem get _current => widget.request.queue[_index];
  PlayerItem? get _next => _index + 1 < widget.request.queue.length
      ? widget.request.queue[_index + 1]
      : null;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: !_forceSoftwareDecode),
    );

    ref.read(preferencesRepositoryProvider).get().then((prefs) {
      if (mounted) _prefs = prefs;
    });

    // Fullscreen + landscape lock is a mobile concern; on desktop these calls
    // can pin the window to a broken size, so keep them phone/tablet-only.
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    _subs.add(_player.stream.playing.listen((v) {
      setState(() => _playing = v);
      // Save on pause (PRD §8.9).
      if (!v && _position > Duration.zero && _duration > Duration.zero) {
        _saveProgress();
      }
    }));
    _subs.add(_player.stream.buffering.listen((v) {
      setState(() => _buffering = v);
    }));
    _subs.add(_player.stream.position.listen((v) {
      setState(() => _position = v);
      _onPosition(v);
    }));
    _subs.add(_player.stream.duration.listen((v) {
      setState(() => _duration = v);
      _onDuration(v);
    }));
    _subs.add(_player.stream.buffer.listen((v) {
      setState(() => _buffer = v);
    }));
    _subs.add(_player.stream.tracks.listen((v) {
      setState(() => _tracks = v);
      _onTracks(v);
    }));
    _subs.add(_player.stream.track.listen((v) {
      setState(() => _selected = v);
    }));
    _subs.add(_player.stream.error.listen((message) {
      setState(() {
        _error = message;
        _controlsVisible = true;
      });
    }));
    // mpv's own log stream — the only place open/decode failures explain
    // themselves. debugPrint is compiled out of release builds.
    _subs.add(_player.stream.log.listen((event) {
      debugPrint('mpv[${event.level}] ${event.prefix}: ${event.text}');
    }));
    _subs.add(_player.stream.completed.listen((completed) {
      if (completed) _onCompleted();
    }));

    _openCurrent(resumeFrom: widget.request.resumeFromSeconds);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save on exit (PRD §8.9) before the player goes away.
    if (_position > Duration.zero && _duration > Duration.zero) {
      _saveProgress();
    }
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    _upNextTimer?.cancel();
    _liveEpgTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    _restoreBrightness();
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Not supported everywhere (desktop) — never fatal.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding: persist position and pause (PRD §8.9).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_position > Duration.zero && _duration > Duration.zero) {
        _saveProgress();
      }
      if (state == AppLifecycleState.paused) _player.pause();
    }
  }

  void _saveProgress() {
    // Live streams have no resume position — some HLS report a rolling
    // duration, so guard explicitly rather than relying on duration == 0.
    if (_current.isLive) return;
    _lastProgressSave = DateTime.now();
    // savePosition applies the §8.9 completion rule (≥95% → completed).
    _progressRepo.savePosition(
      contentKey: _current.contentKey,
      positionSeconds: _position.inSeconds,
      durationSeconds: _duration.inSeconds,
    );
  }

  /// Throttled ~5s ticker while playing (PRD §8.9).
  void _onPosition(Duration position) {
    if (!_playing || _duration == Duration.zero) return;
    if (DateTime.now().difference(_lastProgressSave) >=
        const Duration(seconds: 5)) {
      _saveProgress();
    }
  }

  /// The media just reported its length — this is the moment a pending
  /// resume seek becomes possible.
  void _onDuration(Duration duration) {
    final resume = _pendingResumeSeconds;
    if (resume != null && duration > Duration.zero) {
      _pendingResumeSeconds = null;
      if (resume < duration.inSeconds) {
        _player.seek(Duration(seconds: resume));
      }
    }
  }

  /// Auto-select the preferred audio/subtitle language once per media item
  /// (PRD §8.10) — the headline fix over Smarters.
  void _onTracks(Tracks tracks) {
    if (_autoTracksApplied) return;
    final audio =
        tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subs =
        tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (audio.isEmpty && subs.isEmpty) return;
    _autoTracksApplied = true;

    final wantAudio = _prefs.preferredAudioLang;
    if (wantAudio != null) {
      final match =
          audio.where((t) => _langMatches(t.language, wantAudio)).firstOrNull;
      if (match != null) _player.setAudioTrack(match);
    }

    final wantSubs = _prefs.preferredSubtitleLang;
    if (wantSubs == Preferences.subsOff) {
      _player.setSubtitleTrack(SubtitleTrack.no());
    } else if (wantSubs != null) {
      final match =
          subs.where((t) => _langMatches(t.language, wantSubs)).firstOrNull;
      if (match != null) _player.setSubtitleTrack(match);
    }
  }

  /// Tolerant tag comparison: "en" matches "eng", "nl" matches "nld"/"dut"
  /// won't (different codes) — prefix matching both ways covers the common
  /// 2-vs-3-letter cases panels actually produce.
  bool _langMatches(String? trackLang, String preferred) {
    if (trackLang == null || trackLang.isEmpty) return false;
    final t = trackLang.toLowerCase();
    final p = preferred.toLowerCase();
    return t == p || t.startsWith(p) || p.startsWith(t);
  }

  Future<void> _savePreferences(Preferences prefs) async {
    _prefs = prefs;
    await ref.read(preferencesRepositoryProvider).save(prefs);
    ref.invalidate(preferencesProvider);
  }

  Future<void> _openCurrent({int? resumeFrom}) async {
    setState(() {
      _error = null;
      _upNextCountdown = null;
      _liveNow = null;
    });
    _upNextTimer?.cancel();
    _liveEpgTimer?.cancel();
    try {
      final account = await ref.read(activeAccountProvider.future);
      if (account == null) {
        setState(() => _error = 'No active account.');
        return;
      }
      _autoTracksApplied = false;
      // No explicit resume request (queue advance, retry): pick up stored
      // progress silently when the §8.9 window says so. Live streams never
      // resume.
      if (resumeFrom == null && !_current.isLive) {
        final progress = await _progressRepo.get(_current.contentKey);
        if (_progressRepo.shouldOfferResume(progress)) {
          resumeFrom = progress!.positionSeconds;
        }
      }
      _pendingResumeSeconds = resumeFrom;
      final url = await ref
          .read(sourceFactoryProvider)(account)
          .buildStreamUrl(_current.streamRef);
      await _player.open(Media(url));
      _scheduleHide();
      if (_current.isLive) {
        _refreshLiveEpg();
        _liveEpgTimer = Timer.periodic(
            const Duration(seconds: 60), (_) => _refreshLiveEpg());
      }
    } on Exception catch (e) {
      setState(() => _error = '$e');
    }
  }

  /// Fetches the programme airing now on the live channel (PRD §8.5).
  Future<void> _refreshLiveEpg() async {
    if (!_current.isLive) return;
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    final channel = await ref
        .read(catalogRepositoryProvider)
        .channelById(account, _current.streamRef.streamId);
    if (channel == null) return;
    final programme =
        await ref.read(epgRepositoryProvider).currentProgramme(account, channel);
    if (mounted) setState(() => _liveNow = programme?.title);
  }

  void _onCompleted() {
    // Completion drops it from Continue Watching and, for series,
    // advances the next-unwatched pointer (PRD §8.9).
    _progressRepo.markCompleted(_current.contentKey);
    if (_next == null) {
      setState(() => _controlsVisible = true);
      return;
    }
    // Autoplay-next respecting the user setting (PRD §8.8).
    ref.read(preferencesRepositoryProvider).get().then((prefs) {
      if (!mounted) return;
      if (!prefs.autoplayNext) {
        setState(() => _controlsVisible = true);
        return;
      }
      setState(() => _upNextCountdown = 5);
      _upNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final remaining = (_upNextCountdown ?? 1) - 1;
        if (remaining <= 0) {
          timer.cancel();
          _playNext();
        } else {
          setState(() => _upNextCountdown = remaining);
        }
      });
    });
  }

  void _playNext() {
    if (_next == null) return;
    setState(() => _index += 1);
    _openCurrent();
  }

  // --- Overlay helpers -------------------------------------------------------

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _playing && _error == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _hint(String text) {
    _hintTimer?.cancel();
    setState(() => _gestureHint = text);
    _hintTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gestureHint = null);
    });
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    _player.seek(clamped);
    _hint('${seconds.isNegative ? '−' : '+'}${seconds.abs()}s');
    _scheduleHide();
  }

  // --- Gestures --------------------------------------------------------------

  void _onDoubleTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_locked) return;
    final left = details.localPosition.dx < constraints.maxWidth / 2;
    _seekRelative(left ? -10 : 10);
  }

  void _onVerticalDrag(DragUpdateDetails details, BoxConstraints constraints) {
    if (_locked) return;
    final delta = -details.delta.dy / constraints.maxHeight;
    final left = details.localPosition.dx < constraints.maxWidth / 2;
    if (left) {
      // Brightness (PRD §8.8) — application-level, restored on exit.
      final next = ((_brightness ?? 0.6) + delta).clamp(0.0, 1.0);
      _brightness = next;
      ScreenBrightness()
          .setApplicationScreenBrightness(next)
          .catchError((_) {});
      _hint('Brightness ${(next * 100).round()}%');
    } else {
      _volume = (_volume + delta * 100).clamp(0, 100);
      _player.setVolume(_volume);
      _hint('Volume ${_volume.round()}%');
    }
  }

  void _onHorizontalDragUpdate(
      DragUpdateDetails details, BoxConstraints constraints) {
    if (_locked || _duration == Duration.zero) return;
    // Full width ≈ 90 seconds of scrubbing.
    final deltaSeconds = details.delta.dx / constraints.maxWidth * 90;
    final base = _dragSeekSeconds ?? _position.inSeconds.toDouble();
    final target =
        (base + deltaSeconds).clamp(0.0, _duration.inSeconds.toDouble());
    setState(() => _dragSeekSeconds = target);
    _hint(formatSeconds(target.round()));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final target = _dragSeekSeconds;
    if (target != null) {
      _player.seek(Duration(seconds: target.round()));
      setState(() => _dragSeekSeconds = null);
    }
  }

  // --- Track selection -------------------------------------------------------

  String _audioLabel(AudioTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'None';
    return [track.language, track.title].whereType<String>().join(' — ');
  }

  String _subtitleLabel(SubtitleTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'Off';
    return [track.language, track.title].whereType<String>().join(' — ');
  }

  Future<void> _selectAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
    // Learn on manual change (PRD §8.10): a deliberate switch becomes the
    // new global preference.
    final language = track.language;
    if (language != null && language.isNotEmpty) {
      await _savePreferences(_prefs.copyWith(preferredAudioLang: language));
    }
  }

  Future<void> _selectSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
    if (track.id == 'no') {
      await _savePreferences(
          _prefs.copyWith(preferredSubtitleLang: Preferences.subsOff));
    } else {
      final language = track.language;
      if (language != null && language.isNotEmpty) {
        await _savePreferences(
            _prefs.copyWith(preferredSubtitleLang: language));
      }
    }
  }

  void _showAudioSheet() {
    final tracks =
        _tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    _showTrackSheet<AudioTrack>(
      title: 'Audio',
      tracks: [AudioTrack.auto(), ...tracks],
      selectedId: _selected.audio.id,
      labelOf: _audioLabel,
      onSelected: _selectAudioTrack,
    );
  }

  void _showSubtitleSheet() {
    final tracks =
        _tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    _showTrackSheet<SubtitleTrack>(
      title: 'Subtitles',
      tracks: [SubtitleTrack.no(), ...tracks],
      selectedId: _selected.subtitle.id,
      labelOf: _subtitleLabel,
      onSelected: _selectSubtitleTrack,
    );
  }

  void _showTrackSheet<T>({
    required String title,
    required List<T> tracks,
    required String selectedId,
    required String Function(T) labelOf,
    required Future<void> Function(T) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title, style: AppTypography.title),
            ),
            for (final track in tracks)
              ListTile(
                leading: Icon(
                  (track as dynamic).id == selectedId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: (track as dynamic).id == selectedId
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                title: Text(labelOf(track)),
                onTap: () {
                  onSelected(track);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ).then((_) => _scheduleHide());
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _controller,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
            // Gesture surface.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTapDown: (d) => _onDoubleTapDown(d, constraints),
              onVerticalDragUpdate: (d) => _onVerticalDrag(d, constraints),
              onHorizontalDragUpdate: (d) =>
                  _onHorizontalDragUpdate(d, constraints),
              onHorizontalDragEnd: _onHorizontalDragEnd,
            ),
            if (_buffering && _error == null)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
            if (_error != null) _errorView(),
            if (_gestureHint != null)
              Align(
                alignment: const Alignment(0, -0.7),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_gestureHint!, style: AppTypography.body),
                ),
              ),
            if (_upNextCountdown != null && _next != null) _upNextCard(),
            _controlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openCurrent(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _upNextCard() {
    final next = _next!;
    return Positioned(
      right: 24,
      bottom: 96,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Up next in $_upNextCountdown…',
                style: AppTypography.label
                    .copyWith(color: AppColors.accentAlt)),
            const SizedBox(height: 6),
            Text(next.subtitle ?? next.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: _playNext,
                  child: const Text('Play now'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _upNextTimer?.cancel();
                    setState(() => _upNextCountdown = null);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('LIVE',
              style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const Spacer(),
          if (_buffering)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _controlsOverlay() {
    if (_locked) {
      // Locked: everything hidden except the unlock affordance.
      return AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: IconButton.filledTonal(
                onPressed: () {
                  setState(() => _locked = false);
                  _scheduleHide();
                },
                icon: const Icon(Icons.lock),
                tooltip: 'Unlock controls',
              ),
            ),
          ),
        ),
      );
    }

    final position = _dragSeekSeconds != null
        ? Duration(seconds: _dragSeekSeconds!.round())
        : _position;
    final durationSeconds = _duration.inSeconds;
    final bufferFraction = durationSeconds > 0
        ? (_buffer.inSeconds / durationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0, 0.4, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar: back, title, track + lock actions.
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_current.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title),
                          if (_liveNow != null)
                            Text('Now: $_liveNow',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label
                                    .copyWith(color: AppColors.accentAlt))
                          else if (_current.subtitle != null)
                            Text(_current.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Audio',
                      onPressed: _showAudioSheet,
                      icon: const Icon(Icons.audiotrack_outlined),
                    ),
                    IconButton(
                      tooltip: 'Subtitles',
                      onPressed: _showSubtitleSheet,
                      icon: const Icon(Icons.subtitles_outlined),
                    ),
                    IconButton(
                      tooltip: 'Lock controls',
                      onPressed: () => setState(() {
                        _locked = true;
                        _controlsVisible = true;
                      }),
                      icon: const Icon(Icons.lock_open),
                    ),
                  ],
                ),
                const Spacer(),
                // Center transport.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_current.isLive) ...[
                      IconButton(
                        iconSize: 40,
                        onPressed: () => _seekRelative(-10),
                        icon: const Icon(Icons.replay_10),
                      ),
                      const SizedBox(width: 28),
                    ],
                    IconButton(
                      iconSize: 64,
                      onPressed: () {
                        _player.playOrPause();
                        _scheduleHide();
                      },
                      icon: Icon(_playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                    ),
                    if (!_current.isLive) ...[
                      const SizedBox(width: 28),
                      IconButton(
                        iconSize: 40,
                        onPressed: () => _seekRelative(10),
                        icon: const Icon(Icons.forward_10),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                // Seek bar (VOD) — a LIVE badge replaces it for live streams.
                if (_current.isLive)
                  _liveIndicator()
                else
                  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(formatSeconds(position.inSeconds),
                          style: AppTypography.label),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: LinearProgressIndicator(
                                value: bufferFraction,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                color: Colors.white38,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: AppColors.accent,
                                inactiveTrackColor: Colors.transparent,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                              ),
                              child: Slider(
                                value: durationSeconds > 0
                                    ? position.inSeconds
                                        .clamp(0, durationSeconds)
                                        .toDouble()
                                    : 0,
                                max: durationSeconds > 0
                                    ? durationSeconds.toDouble()
                                    : 1,
                                onChanged: durationSeconds > 0
                                    ? (v) => setState(
                                        () => _dragSeekSeconds = v)
                                    : null,
                                onChangeEnd: (v) {
                                  _player.seek(Duration(seconds: v.round()));
                                  setState(() => _dragSeekSeconds = null);
                                  _scheduleHide();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatSeconds(durationSeconds),
                          style: AppTypography.label),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
