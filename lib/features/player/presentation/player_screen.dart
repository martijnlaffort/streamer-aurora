import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/platform/screen_orientation.dart';
import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/focus_highlight.dart';
import '../../../data/cast/cast_service.dart';
import '../../../data/cast/cast_url.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/watch_progress_repository.dart';
import '../../../data/sync/playback_activity.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../domain/models/models.dart'
    show Account, Preferences, StreamRef, StreamType, contentKeyFor;
import '../../../tour/screenshot_tour.dart' show screenshotTourEnabled;
import '../player_request.dart';
import 'cast_controls.dart';
import 'cast_picker.dart';

/// Android emulators stall on hardware video decode (documented media_kit
/// quirk): run with `--dart-define=DAWN_SW_DECODE=true` there. Real
/// devices keep hardware decoding.
const bool _forceSoftwareDecode = bool.fromEnvironment('DAWN_SW_DECODE');

/// Many Xtream panels serve `player_api.php` to anything but only hand out the
/// actual video to whitelisted player User-Agents — libmpv's default
/// "Lavf/…" gets rejected, so the catalog loads but streams fail to open.
/// Present as VLC, which panels accept almost universally.
const String kStreamUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';

/// One thing worth trying for a channel: a specific stream, reached through a
/// specific one of the account's hosts.
class _StreamCandidate {
  const _StreamCandidate({required this.streamId, required this.hostAttempt});

  final String streamId;

  /// 0 is the account's own `serverUrl`; 1..n index into its fallback hosts.
  final int hostAttempt;
}

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

  /// iOS/Android audio session, activated with the `.playback` category so
  /// audio can legally continue when the app is backgrounded (Task 2.3).
  /// Without an active playback session iOS revokes the `audio` background
  /// assertion and terminates the app.
  AudioSession? _audioSession;

  /// We paused because the OS interrupted us (a call), so we may resume when
  /// it ends. A pause the USER made is never undone by the call finishing.
  bool _pausedByInterruption = false;

  /// Grabbed once so dispose-time saving never touches `ref` late.
  late final WatchProgressRepository _progressRepo =
      ref.read(watchProgressRepositoryProvider);

  /// Same reason as [_progressRepo]. Reading this through `ref` in [dispose]
  /// throws once the element is being unmounted — and because it was the first
  /// statement there, the throw took the rest of dispose with it: no progress
  /// saved, the mpv player never released, and the orientation left locked to
  /// landscape.
  late final PlaybackActivity _playbackActivity =
      ref.read(playbackActivityProvider);

  // Clamped: a caller can hand over a stale or -1 start index (an episode that
  // fell out of a refreshed list), and `queue[_index]` must never RangeError.
  late int _index =
      widget.request.startIndex.clamp(0, widget.request.queue.length - 1);

  // Resume state (PRD §8.9).
  /// The resume seek still to be issued — waiting on a duration it fits in.
  int? _pendingResumeSeconds;

  /// Where this item is meant to resume, until playback is seen actually
  /// running there. See [_checkResume].
  ///
  /// Issuing the seek is not the same as landing it. mpv reports the seek
  /// target as the position the moment it is asked, so the clock showed the
  /// resume point — and then fell back to 0:00 when the seek did not stick (a
  /// panel refusing the ranged request, a TS length estimate still settling).
  /// Nothing looked again, and progress saving carried on from 0:00, writing
  /// over the real resume point within seconds — so the next attempt started
  /// from the beginning too.
  Duration? _resumeTarget;
  int _resumeSeeks = 0;
  DateTime _resumeSeekAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The first position seen running near [_resumeTarget]; landing is
  /// confirmed once the clock has moved on from it.
  Duration? _resumeLandedAt;
  static const _maxResumeSeeks = 3;

  /// End-of-file reports that arrived before the resume landed; see
  /// [_onCompleted].
  int _resumeEndings = 0;
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

  // Rolling tail of interesting mpv log lines — surfaced on the error screen
  // so open/decode failures (HTTP status, refused, format) explain themselves
  // even in release builds where debugPrint is gone.
  final List<String> _diagLog = [];
  bool _showErrorDetails = false;

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

  /// The pre-end "Next episode" prompt is showing. A button, never a countdown:
  /// we are GUESSING where the credits start, and auto-advancing on a guess
  /// would cut off the ending of anything we guessed wrong about.
  bool _upNextEarly = false;
  bool _earlyPrompted = false;

  /// Where the file itself says the credits begin, when it carries chapters.
  /// Exact when present; almost never present on IPTV.
  Duration? _creditsStart;

  /// Seconds before the end at which to offer the next episode when neither
  /// chapters nor a learned value say otherwise. Television credits run
  /// thirty to sixty seconds; this lands the prompt as they start rather than
  /// as they end.
  static const _defaultOutroSeconds = 45;
  int? _learnedOutroSeconds;

  /// The last duration that moved by more than a couple of seconds, and when.
  /// An MPEG-TS episode reports a small, growing length before the real one
  /// lands; anything "near the end" of that is the middle of the episode.
  Duration _settledDuration = Duration.zero;
  DateTime _durationSettledAt = DateTime.now();

  /// Automatic recovery from a dropped stream.
  ///
  /// IPTV transports drop constantly — a few seconds of bad wifi, a panel
  /// hiccup, a re-negotiated CDN edge. Surfacing the error screen on the first
  /// failure turned every one of those into a manual Retry tap, which on a TV
  /// means finding the remote. We now reopen silently a few times first, and
  /// only fall through to the error screen once it is clear the stream is
  /// genuinely gone.
  static const _maxReconnectAttempts = 3;

  /// Where the last early end-of-file happened and how many times running it
  /// has happened there; see [_onCompleted].
  Duration? _cutShortAt;
  int _cutShortCount = 0;
  int _reconnectAttempt = 0;
  bool _reconnecting = false;
  Timer? _reconnectTimer;

  /// Set once the current media has actually produced playback, which is what
  /// makes a later failure a *drop* (worth retrying silently) rather than a
  /// stream that never opened at all. See [_markReallyPlaying].
  bool _everPlayed = false;

  /// The first position reported after the current open, for telling a clock
  /// that is really moving from the one-off jump of a resume seek.
  Duration? _positionAtOpen;

  /// Whether THIS open (first try, reconnect or backup feed) has started.
  bool _startedThisOpen = false;

  /// Start-up timing and stall counts; see [_PlaybackStats].
  final _stats = _PlaybackStats();

  /// Live mpv readings for the stats overlay, polled while it is switched on.
  Timer? _statsTimer;
  Map<String, String> _mpvStats = const {};

  /// What the overlay reads from mpv each second. Each is optional: a build
  /// that does not know one simply leaves its line out.
  static const _statsProperties = [
    'video-params/w',
    'video-params/h',
    'video-codec',
    'hwdec-current',
    'estimated-vf-fps',
    'audio-codec-name',
    'current-ao',
    'avsync',
    'cache-speed',
    'demuxer-cache-duration',
    'frame-drop-count',
    'decoder-frame-drop-count',
  ];

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final platform = _player.platform;
      if (!mounted || platform is! NativePlayer) return;
      final values = <String, String>{};
      for (final property in _statsProperties) {
        try {
          values[property] = await platform.getProperty(property);
        } on Object {
          // Unknown on this build, or nothing to report yet.
        }
      }
      if (mounted) setState(() => _mpvStats = values);
    });
  }

  /// Everything worth trying for the current item, best first.
  ///
  /// A channel is an ordered set of streams, not a URL: a line ships the same
  /// channel two to five times (4K/FHD/HD, backup rows) and they are not
  /// equally healthy. Walking that list silently is the difference between
  /// "reconnects on its own", which is a retry loop against a dead source, and
  /// a channel that simply plays.
  List<_StreamCandidate> _candidates = const [];
  int _candidateIndex = 0;

  /// The logical channel the candidates belong to, for remembering the winner.
  String? _variantKey;

  /// True while walking the candidate list, as opposed to recovering a stream
  /// that had been playing — the two look identical to the code and completely
  /// different to the viewer.
  bool _switchingFeed = false;

  /// Fires when a candidate connects but never starts playing. See
  /// [_watchdogBudget].
  Timer? _watchdog;

  /// Cached channel count for the current zap scope, and the scope it belongs
  /// to. Recomputing it per press is what made channel-up wait on a GROUP BY
  /// over the whole channel table.
  int? _zapTotal;
  String? _zapScopeKey;

  /// Focus node for remote/keyboard input. The player is the one screen where
  /// the entire UI is a video surface, so it owns key handling directly rather
  /// than relying on focus traversal between buttons.
  final _keyboardFocus = FocusNode(debugLabel: 'player-keys');

  /// The play/pause button — the entry point when the remote moves off the
  /// video surface into the on-screen controls. Focusing a concrete control is
  /// the only way in: directional traversal from [_keyboardFocus] has no target
  /// because that node's rect is the whole screen.
  final _playPauseFocus = FocusNode(debugLabel: 'player-playpause');

  // --- Television remote -----------------------------------------------------
  //
  // On a TV the controls come up with the cursor ON them, the way Netflix and
  // HBO do it: the press that reveals them never also seeks, the scrubber
  // previews a target instead of jumping on every press, and BACK steps out
  // one layer at a time (cancel the scrub, hide the controls, leave).

  /// The TV scrubber. LEFT/RIGHT move [_scrubTarget]; OK (or a pause) jumps.
  final _scrubFocus = FocusNode(debugLabel: 'player-scrubber');

  /// The up-next card's main button, or the end-of-episode button — only one
  /// of them is ever on screen.
  final _upNextFocus = FocusNode(debugLabel: 'player-upnext');

  final _retryFocus = FocusNode(debugLabel: 'player-retry');

  /// Wraps the TV controls so "is the cursor somewhere in the controls" can be
  /// asked in one place. Never takes focus itself.
  final _tvControlsRegion = FocusNode(
      debugLabel: 'player-tv-controls',
      canRequestFocus: false,
      skipTraversal: true);

  /// Where the scrubber will jump to, while the viewer is still choosing. Null
  /// when not scrubbing.
  Duration? _scrubTarget;
  Timer? _scrubCommitTimer;

  /// Key repeats in the current hold, for accelerating the scrub step.
  int _scrubRepeats = 0;

  /// The play/pause glyph flashed mid-screen on a TV; see [_togglePlay]. The
  /// count restarts the animation when the same glyph is flashed twice.
  IconData? _flashIcon;
  int _flashCount = 0;
  Timer? _flashTimer;

  /// Whether this build is the television one. Read, not watched: callers are
  /// key handlers and timers, and the answer does not change mid-session.
  bool get _tv => ref.read(isTelevisionProvider).value ?? false;

  // --- Casting ---------------------------------------------------------------
  //
  // Casting is not mirroring: the Chromecast fetches the URL and decodes it
  // itself, so local playback is paused rather than continuing silently, and
  // watch progress is written from the RECEIVER's position while it runs — the
  // whole point is that stopping halfway on the TV still shows up in Continue
  // Watching.
  // --- Timeshift (live) ------------------------------------------------------
  //
  // Pausing and rewinding a live channel needs somewhere to keep what has
  // already gone past. libmpv already has that — its demuxer keeps a back-buffer
  // and will seek inside it — so this is a matter of sizing that buffer and
  // exposing it, not of building a recorder.
  //
  // The buffer is spilled to DISK (`cache-on-disk`) rather than held in RAM.
  // That is the difference between a rewind window measured in seconds and one
  // measured in minutes: half a gigabyte of RAM is not something to ask of a TV
  // stick that is also decoding 1080p, while half a gigabyte of scratch file is
  // unremarkable.
  static const _timeshiftBackBytes = 512 * 1024 * 1024;
  static const _timeshiftForwardBytes = 64 * 1024 * 1024;

  /// Timestamp of the newest buffered packet — i.e. where "live" currently is.
  /// Null until mpv reports it, which is also how we know timeshift is working.
  Duration? _liveEdge;

  bool get _canTimeshift => _current.isLive && _liveEdge != null;

  /// How far behind the live edge playback is. Never negative: the edge and the
  /// position are sampled independently, so they can cross by a few ms.
  Duration get _behindLive {
    final edge = _liveEdge;
    if (edge == null) return Duration.zero;
    final behind = edge - _position;
    return behind.isNegative ? Duration.zero : behind;
  }

  /// Close enough to count as live — a few seconds of slack, because the buffer
  /// end always runs slightly ahead of the decoder.
  bool get _atLiveEdge => _behindLive.inSeconds <= 3;

  StreamSubscription<CastStatus>? _castSub;
  CastStatus _cast = const CastStatus();
  bool _castAvailable = false;

  /// Held from open to exit; null off mobile.
  LandscapeLock? _landscape;
  DateTime _lastCastSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Live zapping state. Starts from the list position the caller handed over
  /// and moves as the user changes channel.
  late ZapContext? _zap = widget.request.zap;

  /// The channel currently playing, when it was reached by zapping rather than
  /// from the queue. Lets the player show the new channel's name and EPG.
  PlayerItem? _zappedItem;
  bool _zapping = false;
  String? _zapToast;
  Timer? _zapToastTimer;

  PlayerItem get _current => _zappedItem ?? widget.request.queue[_index];
  PlayerItem? get _next => _index + 1 < widget.request.queue.length
      ? widget.request.queue[_index + 1]
      : null;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep background catalogue catch-up off the connection while we stream —
    // it is a big enough fetch to show up as buffering.
    _playbackActivity.enter();
    // PopScope's canPop depends on where focus currently sits, and focus
    // changes do not rebuild by themselves.
    _keyboardFocus.addListener(() {
      if (mounted) setState(() {});
    });
    // logLevel: info so the mpv log stream carries HTTP status / open-failure
    // detail (the default `error` level drops it).
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.info),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: !_forceSoftwareDecode),
    );
    unawaited(_configureAudioSession());

    ref.read(preferencesRepositoryProvider).get().then((prefs) {
      if (!mounted) return;
      _prefs = prefs;
      if (prefs.showPlaybackStats) _startStatsPolling();
    });

    // Cast is Android + Play Services only, and is pointless on a television —
    // you are already on the big screen — so the button never appears there.
    final cast = ref.read(castServiceProvider);
    Future(() async {
      final onTv = await ref.read(isTelevisionProvider.future);
      final available = await cast.isAvailable();
      if (!mounted || onTv || !available) return;
      setState(() => _castAvailable = true);
      _castSub = cast.status.listen(_onCastStatus);
    });

    // Fullscreen + landscape for as long as this player is open. Released when
    // the route pops, so the app comes back upright (see LandscapeLock).
    _landscape = LandscapeLock.acquire();

    _subs.add(_player.stream.playing.listen((v) {
      // "Playing" is NOT proof that anything is playing: media_kit reports it
      // inside open(), before a single byte has arrived. See
      // _markReallyPlaying for what counts.
      setState(() => _playing = v);
      // Save on pause (PRD §8.9).
      if (!v && _position > Duration.zero && _duration > Duration.zero) {
        _saveProgress();
      }
    }));
    _subs.add(_player.stream.buffering.listen((v) {
      setState(() => _buffering = v);
      _stats.onBuffering(v, afterStart: _everPlayed);
      if (!v && _everPlayed) _stats.mark('buffer filled');
    }));
    _subs.add(_player.stream.position.listen((v) {
      setState(() => _position = v);
      // Audio-only streams (radio) never report a picture size, so the clock
      // actually moving is the other proof of playback.
      // Re-based when the clock goes backwards (the previous stream's last
      // position can arrive after the open) and after a resume seek.
      final start = _positionAtOpen;
      if (start == null || v < start) {
        _positionAtOpen = v;
      } else if (v - start >= const Duration(seconds: 1)) {
        _markReallyPlaying();
      }
      _onPosition(v);
    }));
    _subs.add(_player.stream.width.listen((w) {
      // A picture size means the decoder produced a frame.
      if (w != null && w > 0) _markReallyPlaying();
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
    _subs.add(_player.stream.error.listen(_onStreamError));
    // mpv's own log stream — the only place open/decode failures explain
    // themselves. debugPrint is compiled out of release builds.
    _subs.add(_player.stream.log.listen((event) {
      debugPrint('mpv[${event.level}] ${event.prefix}: ${event.text}');
      final level = event.level.toLowerCase();
      final text = '${event.prefix}: ${event.text}'.trim();
      final interesting = level == 'error' ||
          level == 'fatal' ||
          level == 'warn' ||
          RegExp(r'(4\d\d|5\d\d|http|tcp|open|host|refused|format|forbidden|denied|unauthor)',
                  caseSensitive: false)
              .hasMatch(text);
      if (interesting && text.isNotEmpty) {
        _diagLog.add(text);
        if (_diagLog.length > 12) _diagLog.removeAt(0);
      }
    }));
    _subs.add(_player.stream.completed.listen((completed) {
      if (completed) _onCompleted();
    }));

    // Registered ONCE, here rather than per open: observeProperty throws if the
    // same property is observed twice, and _openCurrent runs on every zap and
    // queue advance. A build of libmpv that does not know the property just
    // never calls back, and timeshift stays off.
    final platform = _player.platform;
    if (platform is NativePlayer) {
      unawaited(
        platform.observeProperty('demuxer-cache-time', (value) async {
          final seconds = double.tryParse(value);
          // Live only — the edge means nothing for a film — and only when it
          // has moved a quarter second. This fires many times a second, and
          // rebuilding the whole player on every one of them, films included,
          // is CPU a modest TV needs for decoding.
          if (seconds == null || !mounted || !_current.isLive) return;
          final edge = Duration(milliseconds: (seconds * 1000).round());
          final previous = _liveEdge;
          if (previous != null &&
              (edge - previous).abs() < const Duration(milliseconds: 250)) {
            return;
          }
          setState(() => _liveEdge = edge);
        }).catchError((Object _) {}),
      );
      // Chapters, for the rare file that carries them. A chapter called
      // "Credits" is the one exact answer to "where does the outro start",
      // and it costs nothing to look. Arrives as mpv's text form of the node,
      // so it is read leniently rather than parsed as strict JSON.
      unawaited(
        platform.observeProperty('chapter-list', (value) async {
          if (!mounted) return;
          setState(() => _creditsStart = _creditsChapterStart(value));
        }).catchError((Object _) {}),
      );
    }

    _openCurrent(resumeFrom: widget.request.resumeFromSeconds);
  }

  /// Configures and activates the platform audio session with the `.playback`
  /// category so playback owns the output route and can continue in the
  /// background (Task 2.3). Mobile-only; desktop has no session to manage.
  Future<void> _configureAudioSession() async {
    if (!_isMobile) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      _audioSession = session;
      // Pull the earphones out and the video stops - what Netflix and HBO do,
      // and what the platform is asking for: Android's "audio becoming noisy"
      // broadcast and iOS's route change to "old device unavailable" both
      // exist so a film does not start blaring out of the phone speaker on a
      // train. Pause only; never auto-resume when they come back, because the
      // user may have put them away for a reason.
      if (!mounted) return;
      _subs.add(session.becomingNoisyEventStream.listen((_) {
        if (!mounted || !_playing) return;
        _player.pause();
        // Show the controls so the pause is visibly deliberate, not a stall.
        setState(() => _controlsVisible = true);
        _scheduleHide();
      }));
      // A phone call, an alarm, another app taking the audio. The OS has
      // already silenced us; without this the picture keeps running with no
      // sound and the viewer loses a minute of the episode. Pause, and resume
      // only when the platform says the interruption was the pausing kind and
      // it is over - a "duck" (a notification chime) never stops the film.
      _subs.add(session.interruptionEventStream.listen((event) {
        if (!mounted) return;
        if (event.begin) {
          if (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.unknown) {
            _pausedByInterruption = _playing;
            if (_playing) _player.pause();
          }
          return;
        }
        if (_pausedByInterruption &&
            event.type == AudioInterruptionType.pause) {
          _pausedByInterruption = false;
          _player.play();
        } else {
          _pausedByInterruption = false;
        }
      }));
    } catch (_) {
      // Never fatal — playback still works; we just don't own the session.
    }
  }

  @override
  void dispose() {
    // First, so nothing that throws below can leave the app stuck sideways.
    // Usually a no-op: the pop already released it.
    _landscape?.release();
    _castSub?.cancel();
    _playbackActivity.leave();
    WidgetsBinding.instance.removeObserver(this);
    // Save on exit (PRD §8.9) before the player goes away.
    if (_position > Duration.zero && _duration > Duration.zero) {
      _saveProgress();
    }
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    _upNextTimer?.cancel();
    _liveEpgTimer?.cancel();
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    _zapToastTimer?.cancel();
    _scrubCommitTimer?.cancel();
    _flashTimer?.cancel();
    _statsTimer?.cancel();
    _keyboardFocus.dispose();
    _playPauseFocus.dispose();
    _scrubFocus.dispose();
    _upNextFocus.dispose();
    _retryFocus.dispose();
    _tvControlsRegion.dispose();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    // Release the session so other apps' audio can resume.
    final session = _audioSession;
    if (session != null) unawaited(session.setActive(false));
    _restoreBrightness();
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
      // Keep audio going in the background when the user opted in (Task 2.3);
      // otherwise pause to save battery/data.
      if (state == AppLifecycleState.paused && !_prefs.backgroundPlayback) {
        _player.pause();
      }
    }
  }

  void _saveProgress() {
    // Live streams have no resume position — some HLS report a rolling
    // duration, so guard explicitly rather than relying on duration == 0.
    if (_current.isLive) return;
    // Not before the resume point has been reached: the clock still reads
    // where the stream opened (usually 0:00), and saving that would overwrite
    // the place the viewer is trying to get back to.
    if (_resumeTarget != null) return;
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
    _checkResume(position);
    if (!_playing || _duration == Duration.zero) return;
    if (DateTime.now().difference(_lastProgressSave) >=
        const Duration(seconds: 5)) {
      _saveProgress();
    }
    _maybeOfferNext(position);
  }

  /// Offers the next episode as the credits start, not as the file ends.
  ///
  /// Where the credits start is, in order of trust: a chapter the file itself
  /// names, what this show has taught us from earlier skips, and failing both a
  /// default sized for television credits. Whatever the source, this is a
  /// button and never a countdown — the moment is inferred, and auto-advancing
  /// on an inference would cut off the ending of every episode it got wrong.
  ///
  /// Seeking back to well before the offer point withdraws it and re-arms it,
  /// so it comes back when the credits come round again instead of hanging
  /// over the rest of the episode.
  void _maybeOfferNext(Duration position) {
    if (_next == null || _current.isLive || _current.streamRef.isCatchup) {
      return;
    }
    if (!_endIsKnown) return;
    final offerAt = _offerPoint();
    if (_earlyPrompted) {
      if (position < offerAt - const Duration(seconds: 5)) {
        _earlyPrompted = false;
        if (_upNextEarly) setState(() => _upNextEarly = false);
        if (_upNextFocus.hasFocus) _keyboardFocus.requestFocus();
      }
      return;
    }
    if (position < offerAt) return;
    _earlyPrompted = true;
    setState(() => _upNextEarly = true);
    _maybeFocusUpNext();
  }

  /// Whether "near the end" can be trusted: long enough to be an episode, and
  /// a length that has stopped moving. Both next-episode prompts depend on it.
  /// Without it a TS episode reporting ten minutes of a forty-five minute file
  /// put "Next episode" on screen nine minutes in.
  bool get _endIsKnown =>
      _duration >= const Duration(minutes: 5) &&
      DateTime.now().difference(_durationSettledAt) >=
          const Duration(seconds: 10);

  /// Where to offer the next episode.
  ///
  /// A chapter the file names as the credits is trusted, but only in the last
  /// 30% — an "Opening Credits" chapter, or a recap, is not the end. Otherwise
  /// what the show has taught us, or the television default, held to at most
  /// a tenth of the runtime (and three minutes): a learned value can be wrong,
  /// and it must never be able to put the prompt in the middle of an episode.
  Duration _offerPoint() {
    final credits = _creditsStart;
    if (credits != null && credits >= _duration * 0.7 && credits < _duration) {
      return credits;
    }
    final maxLead = (_duration.inSeconds ~/ 10).clamp(15, 180);
    final lead = (_learnedOutroSeconds ?? _defaultOutroSeconds).clamp(15, maxLead);
    return _duration - Duration(seconds: lead);
  }

  /// The media just reported its length — this is the moment a pending
  /// resume seek becomes possible.
  ///
  /// The pending seek is consumed ONLY when we actually perform it — i.e. once
  /// a duration arrives that the resume point falls within. Series episodes are
  /// frequently MPEG-TS, and mpv reports a TS file's duration as 0 or a small,
  /// growing value before it settles on the real length. The old code nulled
  /// the pending resume on that first bogus value without seeking, so the real
  /// duration arrived too late and the episode silently played from the start.
  /// Movies are clean MP4/MKV that report a correct duration at once, which is
  /// why only episodes were affected. Waiting for a usable duration fixes it.
  void _onDuration(Duration duration) {
    if ((duration - _settledDuration).abs() > const Duration(seconds: 2)) {
      _settledDuration = duration;
      _durationSettledAt = DateTime.now();
    }
    final resume = _pendingResumeSeconds;
    if (resume != null && resume < duration.inSeconds) {
      _pendingResumeSeconds = null;
      _seekToResumePoint();
    }
  }

  /// Starts a fresh resume to [seconds] for the media being opened, or clears
  /// it when there is nothing to resume to.
  void _setResumeTarget(int? seconds) {
    final resume = seconds != null && seconds > 0 ? seconds : null;
    _pendingResumeSeconds = resume;
    _resumeTarget = resume == null ? null : Duration(seconds: resume);
    _resumeSeeks = 0;
    _resumeLandedAt = null;
  }

  void _seekToResumePoint() {
    final target = _resumeTarget;
    if (target == null) return;
    _resumeSeeks++;
    _resumeSeekAt = DateTime.now();
    _resumeLandedAt = null;
    _player.seek(target);
    // The jump to the resume point is not playback; measure from there.
    _positionAtOpen = null;
    _stats.mark(_resumeSeeks == 1 ? 'resume seek' : 'resume seek $_resumeSeeks');
  }

  /// Makes sure a resume actually lands, and stays landed.
  ///
  /// Confirmed only once the clock has run on for two seconds near the target:
  /// mpv reports the target as the position the instant it is asked to seek,
  /// so seeing it once proves nothing. If the clock settles somewhere else
  /// instead — back at the start, or wherever an early TS length estimate threw
  /// the seek — it is issued again, a few times, and then given up on out loud
  /// rather than silently.
  void _checkResume(Duration position) {
    final target = _resumeTarget;
    if (target == null || _current.isLive) return;
    final now = DateTime.now();
    if (_pendingResumeSeconds != null) {
      // Still waiting for a length the target fits in. If the length has
      // settled and it never will, the saved point is from some other cut of
      // the file: play from here rather than hold saving off for good.
      if (_everPlayed &&
          _duration > Duration.zero &&
          target >= _duration &&
          now.difference(_durationSettledAt) >= const Duration(seconds: 10)) {
        _abandonResume();
      }
      return;
    }
    // Mid-seek or stalled: the clock is not telling us anything yet.
    if (_buffering ||
        !_playing ||
        now.difference(_resumeSeekAt) < const Duration(milliseconds: 1500)) {
      return;
    }
    final near = (position - target).abs() <= const Duration(seconds: 15);
    if (near) {
      final landed = _resumeLandedAt;
      if (landed == null || position < landed) {
        _resumeLandedAt = position;
      } else if (position - landed >= const Duration(seconds: 2)) {
        _resumeTarget = null;
        _resumeLandedAt = null;
        _stats.mark('resumed');
      }
      return;
    }
    _resumeLandedAt = null;
    if (_resumeSeeks < _maxResumeSeeks && target < _duration) {
      debugPrint('Resume to $target did not stick (at $position); seeking again.');
      _seekToResumePoint();
    } else {
      _abandonResume();
      _toast('Couldn’t pick up at ${formatSeconds(target.inSeconds)} — '
          'this stream wouldn’t skip ahead.');
    }
  }

  /// Stops trying to resume, and lets progress saving carry on from wherever
  /// playback actually is.
  void _abandonResume() {
    _pendingResumeSeconds = null;
    _resumeTarget = null;
    _resumeLandedAt = null;
  }

  /// Where to reopen the current item after a drop, a failed feed or Retry:
  /// the resume point if it has not been reached yet, otherwise where playback
  /// got to. Null lets [_openCurrent] fall back to stored progress.
  int? _reopenAt() {
    if (_current.isLive) return null;
    final target = _resumeTarget;
    if (target != null) return target.inSeconds;
    return _position > Duration.zero ? _position.inSeconds : null;
  }

  /// A seek the viewer asked for. It overrides any resume still being chased —
  /// otherwise rewinding right after a resume would be "corrected" back.
  void _userSeek(Duration target) {
    _abandonResume();
    _player.seek(target);
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
    // Stamp the change so sync's last-write-wins favours this device (§9).
    await ref
        .read(syncConfigStoreProvider)
        .setPreferencesChangedAt(DateTime.now().toUtc());
    ref.invalidate(preferencesProvider);
  }

  /// Opens [_current]. [isRetry] marks an automatic reconnect, which keeps the
  /// attempt counter running; anything else (a queue advance, a manual Retry)
  /// is a fresh start and resets it.
  Future<void> _openCurrent({int? resumeFrom, bool isRetry = false}) async {
    // Start-up timing (Settings → Playback stats, and one logcat line): a
    // fresh clock per item; a reconnect or backup feed is marked on the same
    // clock, so its cost shows up in the total.
    if (isRetry) {
      _stats.mark(_switchingFeed ? 'next feed' : 'reconnect');
    } else {
      _stats.start();
    }
    setState(() {
      _error = null;
      _upNextCountdown = null;
      _upNextEarly = false;
      _earlyPrompted = false;
      _creditsStart = null;
      _settledDuration = Duration.zero;
      _durationSettledAt = DateTime.now();
      _liveNow = null;
      // A new stream has a new buffer; keeping the old edge would report a
      // wildly wrong "behind live" until mpv next reported.
      _liveEdge = null;
      _diagLog.clear();
      _showErrorDetails = false;
      _startedThisOpen = false;
      _positionAtOpen = null;
      // Set here, before any await, so nothing in between saves the old
      // clock over the point being resumed to.
      _setResumeTarget(resumeFrom);
      if (!isRetry) {
        _reconnectAttempt = 0;
        _reconnecting = false;
        _everPlayed = false;
        _cutShortAt = null;
        _cutShortCount = 0;
        _resumeEndings = 0;
        // A different item starts its own walk: the backup that rescued the
        // last channel says nothing about this one.
        _candidateIndex = 0;
        _switchingFeed = false;
      }
    });
    _upNextTimer?.cancel();
    _liveEpgTimer?.cancel();
    try {
      final account = await ref.read(activeAccountProvider.future);
      // Back-out during any of these awaits disposes the widget (and the
      // player). Bail before touching ref/_player/setState on a dead State.
      if (!mounted) return;
      if (account == null) {
        setState(() => _error = 'No active account.');
        return;
      }
      _stats.mark('account');
      _autoTracksApplied = false;
      // No explicit resume request (queue advance, retry): pick up stored
      // progress silently when the §8.9 window says so. Live streams never
      // resume.
      if (resumeFrom == null && !_current.isLive) {
        final progress = await _progressRepo.get(_current.contentKey);
        if (_progressRepo.shouldOfferResume(progress)) {
          _setResumeTarget(progress!.positionSeconds);
        }
      }
      if (!isRetry) {
        await _buildCandidates(account);
        // What this show has taught us about where its credits start.
        final seriesId = _current.seriesId;
        _learnedOutroSeconds = seriesId == null
            ? null
            : await ref
                .read(outroHintsRepositoryProvider)
                .secondsBeforeEnd(account.id, seriesId);
      }
      if (!mounted) return;
      _stats.mark('resume + feeds');
      final candidate = _candidates.isEmpty
          ? _StreamCandidate(
              streamId: _current.streamRef.streamId, hostAttempt: 0)
          : _candidates[_candidateIndex.clamp(0, _candidates.length - 1)];
      final url = _withAltHost(
        await ref.read(sourceFactoryProvider)(account).buildStreamUrl(
              StreamRef(
                accountId: _current.streamRef.accountId,
                type: _current.streamRef.type,
                streamId: candidate.streamId,
                containerExt: _current.streamRef.containerExt,
                catchupStart: _current.streamRef.catchupStart,
                catchupMinutes: _current.streamRef.catchupMinutes,
              ),
            ),
        account,
        candidate.hostAttempt,
      );
      if (!mounted) return;
      _stats.mark('stream url');
      _stats.feed = [
        if (_candidates.length > 1)
          'feed ${_candidateIndex + 1} of ${_candidates.length}',
        if (candidate.hostAttempt > 0) 'backup host ${candidate.hostAttempt}',
        'stream ${candidate.streamId}',
      ].join(' · ');
      // Present a player User-Agent panels accept. Per account, because which
      // string a panel accepts is a property of the provider — see
      // Account.userAgent; kStreamUserAgent is the fallback.
      // Set on the native mpv handle directly — the dedicated `user-agent`
      // property overrides libmpv's default and avoids duplicate headers.
      final platform = _player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty(
            'user-agent', account.userAgent ?? kStreamUserAgent);
        // Only the user's own Audio sync offset, which is zero unless they set
        // one; see _audioDelaySeconds. Always written, so a value from an
        // earlier open never lingers.
        try {
          await platform.setProperty(
              'audio-delay', _audioDelaySeconds().toStringAsFixed(3));
        } on Object {
          // An older libmpv without the property: no compensation, not no
          // playback.
        }
        await _configureCache(platform, live: _current.isLive);
      }
      _stats.mark('player setup');
      await _player.open(Media(url));
      if (!mounted) return;
      _stats.mark('open');
      _armWatchdog();
      _scheduleHide();
      if (_current.isLive) {
        _refreshLiveEpg();
        _liveEpgTimer = Timer.periodic(
            const Duration(seconds: 60), (_) => _refreshLiveEpg());
      }
    } on Exception catch (e) {
      // Same path as a playback failure: building the URL can fail for
      // transient reasons too, and a reconnect in progress should keep trying.
      _onStreamError('$e');
    }
  }

  /// How long a candidate gets to actually start playing before it is written
  /// off and the next one tried.
  ///
  /// Only applied while there is something else to try: the LAST candidate
  /// waits indefinitely. That is what makes an aggressive budget safe — a
  /// healthy-but-slow line walks its list quickly and then sits patiently on
  /// the final entry, rather than being abandoned with nothing playing.
  ///
  /// Four seconds rather than the two a stopwatch would suggest: below that,
  /// a line that is merely slow gets silently demoted to its lowest-quality
  /// row, and the user has no idea why the picture got worse.
  static const _watchdogBudget = Duration(seconds: 4);

  /// Builds the ordered list of things to try for [_current].
  ///
  /// Sources first, then hosts. Walking every source against every host would
  /// be a combinatorial crawl through a dozen dead ends; a stream that is gone
  /// is gone on all of the provider's hostnames, and a blocked host blocks all
  /// of them, so the two failures are independent and one pass each finds them.
  Future<void> _buildCandidates(Account account) async {
    _variantKey = null;
    final ref0 = _current.streamRef;
    // Only live channels have variants. A film has exactly one stream, and a
    // catch-up request is tied to the specific channel that recorded it.
    if (_current.isLive && !ref0.isCatchup) {
      final channel = await ref
          .read(catalogRepositoryProvider)
          .channelById(account, ref0.streamId);
      final key = channel?.variantKey;
      if (key != null) {
        final variants =
            await ref.read(catalogRepositoryProvider).channelVariants(account, key);
        if (variants.length > 1) {
          _variantKey = key;
          final preferred = await ref
              .read(streamChoiceRepositoryProvider)
              .preferred(account.id, key);
          final ids = [for (final v in variants) v.id];
          // A stream the viewer picked by hand leads; otherwise the one that
          // worked last time; everything else keeps its quality order behind.
          // Ignoring the hand pick meant choosing "HD" still opened 4K — on a
          // modest TV or line, the slow start the pick was meant to avoid.
          final lead = _current.pinnedStream ? ref0.streamId : preferred;
          if (lead != null && ids.remove(lead)) {
            ids.insert(0, lead);
          }
          _candidates = [
            for (final id in ids)
              _StreamCandidate(streamId: id, hostAttempt: 0),
            for (var h = 1; h <= account.altHosts.length; h++)
              _StreamCandidate(streamId: ids.first, hostAttempt: h),
          ];
          return;
        }
      }
    }
    _candidates = [
      _StreamCandidate(streamId: ref0.streamId, hostAttempt: 0),
      for (var h = 1; h <= account.altHosts.length; h++)
        _StreamCandidate(streamId: ref0.streamId, hostAttempt: h),
    ];
  }

  /// Moves to the next candidate, if there is one. Returns false when the list
  /// is exhausted and the failure is real.
  bool _tryNextCandidate() {
    if (_candidateIndex + 1 >= _candidates.length) return false;
    setState(() {
      _candidateIndex++;
      _reconnecting = true;
      _switchingFeed = true;
      _error = null;
    });
    // Carry the resume point across: without it the next feed fell back to
    // stored progress, which skips anything under 5% in — a resume at one
    // minute started the episode over.
    _openCurrent(resumeFrom: _reopenAt(), isRetry: true);
    return true;
  }

  /// Arms the "connected but nothing is playing" watchdog.
  ///
  /// A source that accepts the connection and then delivers nothing is the
  /// silent failure this whole feature exists for: without it the player sits
  /// on a black screen forever, because as far as it is concerned nothing has
  /// gone wrong.
  void _armWatchdog() {
    _watchdog?.cancel();
    if (_candidateIndex + 1 >= _candidates.length) return; // nothing to switch to
    _watchdog = Timer(_watchdogBudget, () {
      if (!mounted || _everPlayed) return;
      debugPrint('Candidate $_candidateIndex produced no playback; switching.');
      _tryNextCandidate();
    });
  }

  /// The current media has really started: a decoded frame, or a clock that
  /// has moved a full second.
  ///
  /// Everything that depends on "this stream works" hangs off this rather than
  /// media_kit's `playing`, which fires inside open() before any data arrives.
  /// Trusting `playing` meant the "connected but nothing plays" watchdog never
  /// fired, so backup feeds were never tried; the dead feed was saved as the
  /// winner for next time; and every reconnect reset its own attempt counter.
  void _markReallyPlaying() {
    // Once per open — reconnects included, so a recovered stream clears its
    // "Reconnecting…" overlay too.
    if (_startedThisOpen || !mounted) return;
    _startedThisOpen = true;
    _stats.mark('first frame');
    _stats.logSummary(_current.title);
    setState(() {
      _everPlayed = true;
      // Playback is live again: clear any recovery state so a *later*
      // unrelated drop gets its own full set of attempts rather than
      // inheriting a used-up budget.
      _reconnectAttempt = 0;
      _reconnecting = false;
    });
    // This candidate works: stand the watchdog down and remember it, so the
    // next tune-in does not repeat the walk that found it.
    _watchdog?.cancel();
    _switchingFeed = false;
    _rememberWinner();
  }

  /// Records the stream that actually played, so the next tune-in starts there.
  void _rememberWinner() {
    final key = _variantKey;
    if (key == null || _candidates.isEmpty) return;
    final candidate =
        _candidates[_candidateIndex.clamp(0, _candidates.length - 1)];
    unawaited(() async {
      try {
        final account = await ref.read(activeAccountProvider.future);
        if (account == null) return;
        await ref.read(streamChoiceRepositoryProvider).remember(
              accountId: account.id,
              variantKey: key,
              streamId: candidate.streamId,
            );
      } on Object {
        // Best-effort: forgetting which stream won costs one extra failover.
      }
    }());
  }

  /// Remembers how far before the end the user moved on, for this show.
  ///
  /// Only when it plausibly WAS the credits: inside the repository's bounds,
  /// and only for series episodes — a film has no next episode to learn for.
  void _recordOutroHint() {
    final seriesId = _current.seriesId;
    if (seriesId == null || _current.isLive || !_endIsKnown) return;
    final remaining = (_duration - _position).inSeconds;
    final accountId = _current.streamRef.accountId;
    unawaited(ref.read(outroHintsRepositoryProvider).record(
          accountId: accountId,
          seriesId: seriesId,
          secondsBeforeEnd: remaining,
        ));
  }

  /// The start of a chapter that names itself as the credits, or null.
  ///
  /// [raw] is mpv's string rendering of `chapter-list`, a JSON-ish list of
  /// `{"title":"...","time":123.4}` nodes. Read with two small patterns rather
  /// than a JSON parser: the exact quoting has varied between mpv builds, and a
  /// chapter list that fails to parse should mean "no chapters", never a crash
  /// on open.
  static Duration? _creditsChapterStart(String raw) {
    final entries = RegExp(r'\{[^{}]*\}').allMatches(raw);
    final title = RegExp(r'"title"\s*:\s*"([^"]*)"');
    final time = RegExp(r'"time"\s*:\s*([0-9.]+)');
    final credits = RegExp(r'credit|outro|end\s*card|closing', caseSensitive: false);
    // "Opening Credits" and "Intro" match the word but are the other end of
    // the episode; the first match used to win, so the prompt fired as soon as
    // the opening titles were over.
    final opening = RegExp(r'open|intro|begin|start', caseSensitive: false);
    Duration? latest;
    for (final e in entries) {
      final chunk = e.group(0)!;
      final t = title.firstMatch(chunk)?.group(1);
      if (t == null || !credits.hasMatch(t) || opening.hasMatch(t)) continue;
      final seconds = double.tryParse(time.firstMatch(chunk)?.group(1) ?? '');
      if (seconds == null) continue;
      final at = Duration(milliseconds: (seconds * 1000).round());
      // The LAST credits chapter: end credits come after anything else named
      // like them.
      if (latest == null || at > latest) latest = at;
    }
    return latest;
  }

  /// How long to hold the audio back, in seconds: the user's per-screen Audio
  /// sync offset and nothing else, so out of the box mpv's own A/V sync runs
  /// untouched.
  ///
  /// The app used to add an automatic "compositor lag" delay of two, then
  /// three frame periods (50–60 ms) on every device. Builds before that had
  /// none and were in sync; with it, the picture visibly led the sound. The
  /// guess was wrong, so it is gone rather than retuned.
  double _audioDelaySeconds() => _prefs.audioDelayMs / 1000;

  /// Points [url] at the account's [attempt]-th fallback host.
  ///
  /// Only the origin is swapped — the path and query carry the credentials and
  /// the stream id, and those are the same wherever the provider answers.
  ///
  /// An entry may be written with or without a scheme (`other.host:8080` or
  /// `http://other.host:8080`); without one the original's is kept, so pasting
  /// what the provider emailed you works either way.
  static String _withAltHost(String url, Account account, int attempt) {
    if (attempt <= 0 || attempt > account.altHosts.length) return url;
    final alt = account.altHosts[attempt - 1].trim();
    try {
      final original = Uri.parse(url);
      final replacement =
          Uri.parse(alt.contains('://') ? alt : '${original.scheme}://$alt');
      if (replacement.host.isEmpty) return url;
      return Uri(
        scheme: replacement.scheme,
        userInfo: original.userInfo,
        host: replacement.host,
        // Null means "the scheme's default", which is what a host written
        // without a port should get.
        port: replacement.hasPort ? replacement.port : null,
        path: original.path,
        query: original.hasQuery ? original.query : null,
        fragment: original.hasFragment ? original.fragment : null,
      ).toString();
    } on FormatException {
      return url; // Unparseable entry: leave the original alone.
    }
  }

  /// Sizes libmpv's demuxer cache for what is about to play.
  ///
  /// Live gets a large disk-backed BACK-buffer, which is what makes pause and
  /// rewind possible on a stream the server will not let you seek in;
  /// `force-seekable` is what stops mpv refusing the seek outright. VOD is
  /// explicitly put back to a small in-memory buffer, because the server can
  /// seek it properly and leaving a half-gigabyte scratch file behind for
  /// something that never needs one would be careless.
  ///
  /// Every call is individually tolerant of failure: an older libmpv may not
  /// know a property, and the correct outcome there is "no timeshift", not "no
  /// playback".
  Future<void> _configureCache(NativePlayer platform,
      {required bool live}) async {
    Future<void> set(String property, String value) async {
      try {
        await platform.setProperty(property, value);
      } on Object {
        // Unknown or read-only on this build — skip it.
      }
    }

    if (!live) {
      await set('cache-on-disk', 'no');
      await set('demuxer-max-back-bytes', '${32 * 1024 * 1024}');
      _stats.cacheMode = 'memory';
      return;
    }

    // Scratch space for the back-buffer. Falls back to a RAM-only buffer if the
    // directory cannot be resolved, which still gives a short rewind window.
    String? dir;
    try {
      dir = '${(await getTemporaryDirectory()).path}/dawn-timeshift';
      await Directory(dir).create(recursive: true);
    } on Object {
      dir = null;
    }
    await set('cache', 'yes');
    if (dir != null) {
      await set('cache-dir', dir);
      await set('cache-on-disk', 'yes');
    }
    await set('demuxer-max-back-bytes', '$_timeshiftBackBytes');
    await set('demuxer-max-bytes', '$_timeshiftForwardBytes');
    await set('force-seekable', 'yes');
    _stats.cacheMode =
        dir != null ? 'disk (timeshift)' : 'memory (timeshift)';
  }

  /// Jump back to the live edge. Deliberately a second short of it — seeking to
  /// the exact end of the buffer lands on data the decoder has not caught up
  /// with and stalls.
  void _goLive() {
    final edge = _liveEdge;
    if (edge == null) return;
    final target = edge - const Duration(seconds: 1);
    _userSeek(target.isNegative ? Duration.zero : target);
    _player.play();
    _wake();
  }

  /// Fetches the programme airing now on the live channel (PRD §8.5).
  Future<void> _refreshLiveEpg() async {
    if (!_current.isLive) return;
    final account = await ref.read(activeAccountProvider.future);
    // Fires on a 60s timer; the widget may be long gone by the time it resolves.
    if (!mounted || account == null) return;
    final channel = await ref
        .read(catalogRepositoryProvider)
        .channelById(account, _current.streamRef.streamId);
    if (!mounted || channel == null) return;
    // Cache only. This runs as the channel starts and every minute after; with
    // refresh on, a stale guide meant the whole XMLTV file (often hundreds of
    // megabytes) was downloaded and parsed while the stream was trying to
    // start. The guide refreshes itself once nothing is playing.
    final programme = await ref
        .read(epgRepositoryProvider)
        .currentProgramme(account, channel, refresh: false);
    if (mounted) setState(() => _liveNow = programme?.title);
  }

  /// A stream failed. Retry quietly a few times before admitting defeat —
  /// see [_maxReconnectAttempts].
  void _onStreamError(String message) {
    if (!mounted) return;
    // A stream that never opened may be nothing worse than this particular
    // row of the channel, or this particular hostname. Walk the rest before
    // reporting a failure — doing that by hand is the debugging session this
    // is meant to end.
    if (!_everPlayed && _tryNextCandidate()) return;
    // A stream that never opened is usually a real problem (wrong URL, denied,
    // offline) and retrying it just delays a useful message. A stream that was
    // playing and stopped is a drop, and is worth reopening.
    if (_everPlayed && _reconnectAttempt < _maxReconnectAttempts) {
      _scheduleReconnect();
      return;
    }
    setState(() {
      _error = message;
      _reconnecting = false;
      _controlsVisible = true;
    });
  }

  /// Reopens the current item after a backoff, resuming where it dropped.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempt + 1;
    // 1s, 2s, 4s — long enough for a brief outage to pass, short enough that a
    // recoverable blip doesn't feel like a failure.
    final delay = Duration(seconds: 1 << (attempt - 1));
    setState(() {
      _reconnectAttempt = attempt;
      _reconnecting = true;
      _error = null;
    });
    // Live has no meaningful resume point; VOD picks up where it stopped — or
    // where it was still trying to resume to.
    final resumeFrom = _reopenAt();
    _reconnectTimer = Timer(delay, () {
      if (mounted) _openCurrent(resumeFrom: resumeFrom, isRetry: true);
    });
  }

  void _onCompleted() {
    // A live stream does not "complete" — if it reports completion the feed
    // dropped, and stopping here would leave a dead screen with the channel
    // apparently still on. Recover it the same way as an error.
    if (_current.isLive) {
      if (_reconnectAttempt < _maxReconnectAttempts) {
        _scheduleReconnect();
      } else {
        setState(() {
          _error = 'The channel stopped responding.';
          _reconnecting = false;
          _controlsVisible = true;
        });
      }
      return;
    }
    // A dropped connection can surface as end-of-file. Only a position at the
    // end is the end: anything earlier is recovered like an error, resuming
    // where it stopped — not marked watched, and no countdown to the next
    // episode. Once the retries are spent, fall through and treat it as the
    // end after all: a file whose header overstates its length really does
    // finish early, every time.
    // Ending before the resume point was even reached is never the end of the
    // episode: a seek past an early, too-short length estimate can do this.
    // Never mark it watched on that basis.
    // Counted separately from _reconnectAttempt, which a successful reopen
    // resets, so this cannot go round forever.
    if (_resumeTarget != null) {
      if (_resumeEndings++ < 2) {
        _scheduleReconnect();
      } else {
        _abandonResume();
        setState(() => _controlsVisible = true);
      }
      return;
    }
    final cutShort = _duration > Duration.zero &&
        _position < _duration * 0.97 &&
        _duration - _position > const Duration(seconds: 10);
    if (cutShort) {
      // Counted per spot rather than by _reconnectAttempt, which a successful
      // reopen resets — a file that always ends at the same place would
      // otherwise reconnect forever.
      final last = _cutShortAt;
      final again = last != null &&
          (_position - last).abs() < const Duration(seconds: 15);
      _cutShortCount = again ? _cutShortCount + 1 : 1;
      _cutShortAt = _position;
      if (_cutShortCount <= 2 && _reconnectAttempt < _maxReconnectAttempts) {
        _scheduleReconnect();
        return;
      }
    }
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
      // The end arrived: the early offer hands over to the countdown rather
      // than the two cards sitting on top of each other.
      setState(() {
        _upNextEarly = false;
        _upNextCountdown = 5;
      });
      // The episode is over, so OK should mean "play it now".
      _maybeFocusUpNext();
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

  bool get _hasPrevious => _index > 0;

  /// [fromOffer] marks a press on one of the next-episode prompts, as opposed
  /// to the transport's skip button or the remote's next key.
  void _playNext({bool fromOffer = false}) {
    if (_next == null) return;
    // Moving on with time still to play is the signal this whole feature
    // learns from: it says where THIS show's credits start. Recorded before
    // anything about the current item is cleared — but only from the prompt,
    // or a skip in the last 15%. A skip ten minutes in is "not this one", not
    // "the credits start here"; learning from it walked the prompt forward
    // into the middle of every later episode.
    if (fromOffer || (_endIsKnown && _position >= _duration * 0.85)) {
      _recordOutroHint();
    }
    // Manual skip: save where we left the current item first (PRD §8.9).
    _saveProgress();
    _upNextTimer?.cancel();
    // A reconnect scheduled for THIS item would otherwise reopen the next one
    // at this one's position.
    _reconnectTimer?.cancel();
    // The prompt that was pressed is about to disappear; keep the remote on
    // something that exists.
    if (_upNextFocus.hasFocus) _keyboardFocus.requestFocus();
    setState(() {
      _index += 1;
      _upNextCountdown = null;
      // Clear transport state for the new item. Otherwise a quick exit before
      // it reports its own position/duration would save the PREVIOUS item's
      // position against the NEW item's content key (dispose saves whenever
      // position & duration are both > 0).
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _openCurrent();
  }

  void _playPrevious() {
    if (!_hasPrevious) return;
    _saveProgress();
    _upNextTimer?.cancel();
    _reconnectTimer?.cancel();
    setState(() {
      _index -= 1;
      _upNextCountdown = null;
      // See _playNext: clear so a quick exit can't misattribute the position.
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _openCurrent();
  }

  // --- Overlay helpers -------------------------------------------------------

  void _scheduleHide() {
    // A screenshot of the player with its controls faded out is a screenshot of
    // a video, not of an app. Nothing taps this simulator, so the chrome would
    // never come back.
    if (screenshotTourEnabled) return;
    _hideTimer?.cancel();
    // Five seconds on a television, as Netflix does: reading a remote's
    // buttons from a sofa is slower than a thumb, and 3.2 s hid the controls
    // mid-thought.
    final delay = _tv
        ? const Duration(seconds: 5)
        : const Duration(milliseconds: 3200);
    _hideTimer = Timer(delay, () {
      if (!mounted) return;
      // Not while choosing a scrub target, and not from under an open audio or
      // subtitle sheet: hiding used to move focus to the video underneath the
      // sheet, and the arrows then scrubbed the film instead of the list.
      if (_scrubTarget != null || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        _scheduleHide();
        return;
      }
      if (_playing && _error == null) {
        setState(() => _controlsVisible = false);
        // If the remote was parked on a control, hand it back to the video
        // surface as the controls fade — otherwise it would keep driving a
        // button that is no longer visible. The up-next card stays put: it is
        // on screen whether or not the controls are.
        if (!_keyboardFocus.hasPrimaryFocus && !_upNextFocus.hasFocus) {
          _keyboardFocus.requestFocus();
        }
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  /// Gesture feedback is glanceable and gone; an explanation ("a Chromecast
  /// can't play .mkv") has to stay up long enough to read.
  void _hint(String text,
      {Duration duration = const Duration(milliseconds: 900)}) {
    _hintTimer?.cancel();
    setState(() => _gestureHint = text);
    _hintTimer = Timer(duration, () {
      if (mounted) setState(() => _gestureHint = null);
    });
  }

  /// Whether channel up/down is available: a live stream launched from a
  /// channel list. Catch-up playback is a recording, so zapping off it would be
  /// surprising — it is excluded.
  bool get _canZap =>
      _zap != null && _current.isLive && !_current.streamRef.isCatchup;

  /// Channel up (+1) / down (-1), wrapping at both ends.
  ///
  /// Neighbours are resolved one row at a time from the catalogue rather than
  /// from an in-memory list — see [ZapContext].
  Future<void> _zapBy(int delta) async {
    final zap = _zap;
    if (zap == null || _zapping) return;
    _zapping = true;
    // Paint BEFORE any I/O. A remote press has to produce visible feedback
    // immediately — Roku certifies 250 ms for it — and the banner used to wait
    // on a channel count, an overrides read and a row lookup first. On a 25k
    // line that count is a GROUP BY over the whole table, so the one
    // interaction people repeat all evening was the one that waited longest.
    //
    // The position is predicted from the cached total; if there isn't one yet
    // the direction is still something, and both are corrected below the
    // moment the real row arrives.
    final knownTotal = _zapTotal;
    _showZapToast(knownTotal != null && knownTotal > 0
        ? '${(zap.index + delta) % knownTotal + 1}/$knownTotal · …'
        : (delta > 0 ? 'Channel up…' : 'Channel down…'));
    try {
      final account = await ref.read(activeAccountProvider.future);
      if (!mounted || account == null) return;
      final catalog = ref.read(catalogRepositoryProvider);
      // Grouping has to match the list the index came from, or channel-up steps
      // through per-quality duplicates the user cannot see on the Live tab.
      final grouped = ref.read(groupChannelVariantsProvider);
      // Hidden channels have to come out here too. channelCount's own comment
      // says the list, the count and zapping must match exactly — and this call
      // site was the one that did not, so channel-up walked into channels the
      // user had explicitly hidden and could not see on the Live tab. Read
      // fresh rather than carried on ZapContext: the set is the user's current
      // curation, which now also arrives from other devices mid-session.
      final overrides = await ref.read(catalogOverridesProvider.future);
      if (!mounted) return;
      final hidden = overrides.hiddenChannels;
      // Counting is the expensive half — grouped, it is a GROUP BY over every
      // channel — and the answer only moves when the scope or the hidden set
      // does. Cache it so holding channel-up costs one indexed row read per
      // press instead of a full recount.
      final scopeKey = '${zap.categoryId}|${zap.categoryIds?.length}'
          '|$grouped|${hidden.length}';
      if (_zapTotal == null || _zapScopeKey != scopeKey) {
        _zapTotal = await catalog.channelCount(
          account,
          categoryId: zap.categoryId,
          categoryIds: zap.categoryIds,
          excludeIds: hidden,
          groupVariants: grouped,
        );
        _zapScopeKey = scopeKey;
      }
      final total = _zapTotal!;
      if (total <= 1) {
        _showZapToast('No other channels in this list');
        return;
      }
      final nextIndex = (zap.index + delta) % total;
      final channel = await catalog.channelAt(
        account,
        nextIndex,
        categoryId: zap.categoryId,
        categoryIds: zap.categoryIds,
        excludeIds: hidden,
        groupVariants: grouped,
      );
      if (channel == null || !mounted) return;
      _saveProgress();
      _reconnectTimer?.cancel();
      // The name the LIVE LIST shows: its base name when qualities are grouped,
      // and any rename the user gave it. Showing the raw provider row here
      // ("NL | NPO 1 FHD") — on the player title or the zap toast — after they
      // renamed it to "NPO 1" reads as landing on a different channel, so the
      // title and the toast share this one resolved label.
      final label = overrides.channelName(
          channel.id, grouped ? channel.displayName : channel.name);
      setState(() {
        _zap = zap.withIndex(nextIndex);
        _zappedItem = PlayerItem(
          streamRef: StreamRef(
            accountId: channel.accountId,
            type: StreamType.live,
            streamId: channel.id,
          ),
          title: label,
          contentKey: contentKeyFor(
              accountId: channel.accountId,
              type: StreamType.live,
              id: channel.id),
          isLive: true,
        );
      });
      _showZapToast('${nextIndex + 1}/$total · $label');
      await _openCurrent();
    } finally {
      _zapping = false;
    }
  }

  /// Brief channel banner after a zap — the one piece of feedback that makes
  /// holding channel-up feel like a TV rather than a series of blind jumps.
  void _showZapToast(String text) {
    _zapToastTimer?.cancel();
    if (!mounted) return;
    setState(() => _zapToast = text);
    _zapToastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _zapToast = null);
    });
  }

  /// Brings the overlay back and restarts the auto-hide countdown.
  ///
  /// Every remote press routes through here, and that is the point: the
  /// controls hid themselves after 3.2 seconds and *tap* was the only thing
  /// that brought them back, so on a television they became unreachable the
  /// first time they faded.
  void _wake() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// TV: brings the controls up WITH the cursor on them — on [focus] when
  /// given, otherwise on the scrubber when there is something to scrub, and
  /// on play/pause when there is not.
  ///
  /// The video surface never keeps the cursor while the controls show: the
  /// same RIGHT used to either walk the buttons or seek depending on a state
  /// nobody could see.
  void _revealControls({FocusNode? focus}) {
    _wake();
    // After the frame: hidden controls are excluded from focus, and are only
    // focusable again once they have rebuilt as visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _error != null) return;
      (focus ?? (_hasTvScrubber ? _scrubFocus : _playPauseFocus))
          .requestFocus();
    });
  }

  /// Play/pause from the remote, with a big glyph in the middle of the picture
  /// on a television — from across the room the small button changing shape
  /// is easy to miss, and a press with no visible answer gets pressed again.
  void _togglePlay() {
    final willPlay = !_playing;
    _player.playOrPause();
    if (_tv) _flash(willPlay ? Icons.play_arrow_rounded : Icons.pause_rounded);
  }

  void _flash(IconData icon) {
    _flashTimer?.cancel();
    setState(() {
      _flashIcon = icon;
      _flashCount++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashIcon = null);
    });
  }

  bool get _hasTvScrubber => !_current.isLive && _duration > Duration.zero;

  bool get _upNextShowing =>
      ((_upNextCountdown != null || _upNextEarly) && _next != null) ||
      _shouldShowNextEpisode();

  bool _isOk(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA;

  /// The remote's dedicated media and channel keys. They do the same thing
  /// wherever the cursor is — they used to be dropped whenever a control had
  /// focus, which is most of the time on a TV.
  bool _handleMediaKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      _wake();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _player.play();
      _wake();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _player.pause();
      _wake();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaRewind) {
      if (!_current.isLive || _canTimeshift) {
        _seekRelative(-10);
      } else {
        _wake();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      if (!_current.isLive || (_canTimeshift && !_atLiveEdge)) {
        _seekRelative(10);
      } else {
        _wake();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      if (_next != null) _playNext();
      _wake();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (_hasPrevious) _playPrevious();
      _wake();
      return true;
    }
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown) {
      if (_canZap) {
        unawaited(_zapBy(key == LogicalKeyboardKey.channelUp ? 1 : -1));
      }
      _wake();
      return true;
    }
    return false;
  }

  /// Remote and keyboard input.
  ///
  /// Handled here at the top of the player rather than by focus traversal
  /// between the overlay's buttons: a video player's primary controls are the
  /// directional pad itself, not a set of widgets you tab through.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (_handleMediaKey(key)) return KeyEventResult.handled;

    // Key events bubble up from whatever descendant holds focus. Once the user
    // has moved into the overlay's buttons, the arrows belong to focus
    // traversal — hijacking them here would make the buttons unreachable, since
    // moving between them IS left/right.
    if (!_keyboardFocus.hasPrimaryFocus) {
      _wake();
      // OK/centre activates the focused control. D-pad centre arrives as
      // `select` on many televisions, which is NOT in Flutter's default
      // activation shortcuts, so trigger the focused control ourselves.
      // Everything else (arrows) falls through to traversal; the TV scrubber
      // never gets here, it handles its own keys (see _onScrubKey).
      if (_isOk(key)) {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx != null) Actions.maybeInvoke(ctx, const ActivateIntent());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Locked: swallow everything except the wake, so the unlock button can be
    // focused. This mirrors the touch behaviour.
    if (_locked) {
      _wake();
      return KeyEventResult.handled;
    }

    // Play/pause — the D-pad centre. On a TV the controls come up with it, so
    // pausing shows where you are and the scrubber is ready to move.
    if (_isOk(key)) {
      if (_tv && _error != null) {
        _retryFocus.requestFocus();
        return KeyEventResult.handled;
      }
      _togglePlay();
      _tv ? _revealControls() : _wake();
      return KeyEventResult.handled;
    }

    if (_tv) return _onTvSurfaceArrow(event);

    // Phone, tablet and desktop keyboards: the arrows seek straight away, the
    // way every desktop player does. On a live stream there is nothing to
    // seek through, so they only wake the overlay.
    if (key == LogicalKeyboardKey.arrowLeft) {
      // Live can be scrubbed too now, as far back as the timeshift buffer goes.
      if (!_current.isLive || _canTimeshift) {
        _seekRelative(-10);
      } else {
        _wake();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      // Forward only means something when there is buffered future to move
      // into, i.e. when we are behind the live edge.
      if (!_current.isLive) {
        _seekRelative(10);
      } else if (_canTimeshift && !_atLiveEdge) {
        _seekRelative(10);
      } else {
        _wake();
      }
      return KeyEventResult.handled;
    }

    // Up/down zap while watching live, where changing channel is the thing
    // you actually want them for; otherwise they move into the controls.
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_canZap) {
        unawaited(_zapBy(key == LogicalKeyboardKey.arrowUp ? 1 : -1));
        _wake();
        return KeyEventResult.handled;
      }
      // Move the remote off the video surface and into the on-screen controls,
      // landing on play/pause. From there directional traversal reaches the
      // top bar, the transport buttons and the seek bar; Back (PopScope) steps
      // back out to plain viewing, where left/right scrub again. This explicit
      // hand-off is necessary because traversal from the full-screen key node
      // has no target of its own.
      _wake();
      _playPauseFocus.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// TV, cursor on the video itself (so the controls are normally hidden).
  ///
  /// Every arrow does what it would do with the controls already up, and
  /// brings them up while it does it: LEFT/RIGHT start choosing a new spot on
  /// the scrubber, DOWN lands on the buttons, UP on the scrubber (or the
  /// up-next prompt). A first press that only revealed the controls meant
  /// every skip took two presses, and the first one seemed to be ignored.
  KeyEventResult _onTvSurfaceArrow(KeyEvent event) {
    final key = event.logicalKey;
    final up = key == LogicalKeyboardKey.arrowUp;
    final vertical = up || key == LogicalKeyboardKey.arrowDown;
    final horizontal = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (!vertical && !horizontal) return KeyEventResult.ignored;
    if (_error != null) {
      _retryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    // Watching live with nothing on screen, the D-pad's up/down are the
    // channel keys a television viewer expects — and they must not bring the
    // controls up, or holding channel-up would stop zapping after one press.
    if (vertical && _canZap && !_controlsVisible) {
      unawaited(_zapBy(up ? 1 : -1));
      return KeyEventResult.handled;
    }
    // UP while an up-next prompt is on screen goes straight to it: it sits
    // above everything else.
    if (up && _upNextShowing) {
      _wake();
      _upNextFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (horizontal && _hasTvScrubber) {
      // Held, the repeats keep arriving here until the scrubber has focus;
      // they step the same target either way, so the hold accelerates as one.
      _revealControls(focus: _scrubFocus);
      _scrubStep(
          forward: key == LogicalKeyboardKey.arrowRight,
          repeat: event is KeyRepeatEvent);
      return KeyEventResult.handled;
    }
    _revealControls(
        focus: key == LogicalKeyboardKey.arrowDown ? _playPauseFocus : null);
    return KeyEventResult.handled;
  }

  /// TV scrubber keys. LEFT/RIGHT move a target rather than seeking on every
  /// press: the old scrubber was a stock Slider, which seeked 5% of the film
  /// per press and also claimed UP/DOWN, so there was no way off it but BACK.
  KeyEventResult _onScrubKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _scrubStep(
          forward: key == LogicalKeyboardKey.arrowRight,
          repeat: event is KeyRepeatEvent);
      return KeyEventResult.handled;
    }
    if (_isOk(key)) {
      if (_scrubTarget != null) {
        _commitScrub(play: true);
      } else {
        _togglePlay();
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _commitScrub();
      _playPauseFocus.requestFocus();
      _scheduleHide();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_upNextShowing) {
        _commitScrub();
        _upNextFocus.requestFocus();
      }
      // Nothing else above the scrubber; handled so focus cannot wander off
      // to something that is not on screen.
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Moves the scrub target one step. 10 s a press; held, it speeds up to 30 s
  /// and then a minute, so a two-hour film can be crossed without forty
  /// presses.
  void _scrubStep({required bool forward, required bool repeat}) {
    _scrubRepeats = repeat ? _scrubRepeats + 1 : 0;
    final step = _scrubRepeats >= 20
        ? 60
        : _scrubRepeats >= 6
            ? 30
            : 10;
    var target =
        (_scrubTarget ?? _position) + Duration(seconds: forward ? step : -step);
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    setState(() => _scrubTarget = target);
    _hideTimer?.cancel();
    // Commits by itself once the viewer stops pressing, so nobody has to know
    // that OK confirms; OK just does it sooner.
    _scrubCommitTimer?.cancel();
    _scrubCommitTimer = Timer(const Duration(milliseconds: 1500), _commitScrub);
  }

  /// Jumps to the scrub target, if one is being chosen.
  void _commitScrub({bool play = false}) {
    _scrubCommitTimer?.cancel();
    final target = _scrubTarget;
    if (target == null) return;
    _userSeek(target);
    if (play) _player.play();
    // Moved here now rather than when mpv next reports, so the playhead does
    // not snap back to the old spot for a moment.
    setState(() {
      _scrubTarget = null;
      _position = target;
    });
    _scheduleHide();
  }

  void _cancelScrub() {
    _scrubCommitTimer?.cancel();
    setState(() => _scrubTarget = null);
    _scheduleHide();
  }

  /// TV transport row: UP goes back to the scrubber (or the up-next prompt
  /// when there is no scrubber), and DOWN stays put — there is nothing below,
  /// and letting traversal pick a target is how focus used to land on things
  /// that were not visible.
  KeyEventResult _onTvRowKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_hasTvScrubber) {
        _scrubFocus.requestFocus();
      } else if (_upNextShowing) {
        _upNextFocus.requestFocus();
      }
      _scheduleHide();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _scheduleHide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// TV up-next prompt: DOWN drops into the controls.
  KeyEventResult _onUpNextKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _revealControls();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// TV: puts the cursor on an up-next prompt that has just appeared — but
  /// only in the final minute (or at a chapter the file names as the credits).
  /// Earlier, grabbing focus would turn the OK meant as "pause" into "skip to
  /// the next episode".
  void _maybeFocusUpNext() {
    if (!_tv) return;
    final remaining = _duration - _position;
    final atCredits =
        _creditsStart != null && _position >= _creditsStart!;
    if (_upNextCountdown == null &&
        remaining > const Duration(seconds: 60) &&
        !atCredits) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _upNextShowing) _upNextFocus.requestFocus();
    });
  }

  // --- Casting ---------------------------------------------------------------

  void _onCastStatus(CastStatus status) {
    if (!mounted) return;
    final wasCasting = _cast.isCasting;
    setState(() => _cast = status);

    // The receiver is authoritative while it plays, so progress comes from it.
    // Live has no meaningful position, and a zero duration means it has not
    // reported yet.
    if (status.isCasting &&
        !_current.isLive &&
        status.durationSeconds > 0 &&
        status.positionSeconds > 0) {
      final now = DateTime.now();
      if (now.difference(_lastCastSave) >= const Duration(seconds: 10)) {
        _lastCastSave = now;
        _progressRepo.savePosition(
          contentKey: _current.contentKey,
          positionSeconds: status.positionSeconds,
          durationSeconds: status.durationSeconds,
        );
      }
    }

    // The session ended on the device (someone stopped it from another app, or
    // the TV was switched off). Pick playback back up here at wherever it got
    // to, which is what the user expects to see when the TV goes away.
    if (wasCasting && !status.isCasting) {
      final resumeAt = _cast.positionSeconds;
      if (!_current.isLive && resumeAt > 0) {
        _userSeek(Duration(seconds: resumeAt));
      }
      _player.play();
    }
  }

  /// Hand the current stream to a Chromecast (Android) or AirPlay (iPhone).
  Future<void> _startCasting() async {
    final account = await ref.read(activeAccountProvider.future);
    if (!mounted || account == null) return;

    final String url;
    try {
      url = await ref
          .read(sourceFactoryProvider)(account)
          .buildStreamUrl(_current.streamRef);
    } on Object catch (e) {
      if (mounted) _toast('$e');
      return;
    }
    if (!mounted) return;

    final cast = ref.read(castServiceProvider);
    // Decided in one place, because "can this be cast?" is entirely a question
    // about the container — see castTargetFor. What neither kind of device
    // can play is refused before anyone is asked to pick one.
    final target = castTargetFor(_current.streamRef, url);
    if (!target.canCast) {
      _toast(target.refusal!);
      return;
    }

    // Save where we are before handing over, so nothing is lost if the cast
    // fails, and pause here — two copies playing at once is the classic bug.
    _saveProgress();
    await _player.pause();
    if (!mounted) return;

    final picked = await showCastPicker(context);
    if (!mounted) return;
    if (picked == null) {
      // Backed out — carry on watching here.
      if (!_cast.isCasting) await _player.play();
      return;
    }

    // AirPlay (iPhone): Apple's own list chooses the device, and choosing one
    // starts the stream on it. The status stream then shows the casting view,
    // exactly as for a Chromecast.
    if (picked == CastPick.airPlay) {
      final airTarget =
          castTargetFor(_current.streamRef, url, airPlay: true);
      if (!airTarget.canCast) {
        _toast(airTarget.refusal!);
        await _player.play();
        return;
      }
      ref
          .read(castNowPlayingProvider.notifier)
          .set(_current.title, _current.subtitle);
      final started = await cast.airPlay(
        url: airTarget.url!,
        isLive: airTarget.isLive,
        title: _current.title,
        subtitle: _current.subtitle,
        positionSeconds: _current.isLive ? 0 : _position.inSeconds,
      );
      // Closed without choosing a device — carry on watching here.
      if (mounted && !started && !_cast.isCasting) await _player.play();
      return;
    }

    // Remember what we handed over, so the browse-shell mini bar and remote
    // sheet can name it if the user leaves the player while it is still casting.
    ref
        .read(castNowPlayingProvider.notifier)
        .set(_current.title, _current.subtitle);
    try {
      await cast.load(
            url: target.url!,
            contentType: target.contentType!,
            isLive: target.isLive,
            title: _current.title,
            subtitle: _current.subtitle,
            positionSeconds: _current.isLive ? 0 : _position.inSeconds,
          );
    } on PlatformException catch (e) {
      if (mounted) {
        _toast(e.message ?? 'That device would not accept the stream.');
        await _player.play();
      }
    }
  }

  Future<void> _stopCasting() async {
    await ref.read(castServiceProvider).disconnect();
  }

  /// Message that needs reading, not glancing at.
  void _toast(String message) {
    _hint(message, duration: const Duration(seconds: 4));
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    // A live stream has no duration to clamp against — the ceiling is the live
    // edge, kept a second short so a forward seek cannot land on undecoded data.
    final ceiling = _current.isLive
        ? (_liveEdge == null
            ? null
            : _liveEdge! - const Duration(seconds: 1))
        : (_duration > Duration.zero ? _duration : null);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (ceiling != null && target > ceiling ? ceiling : target);
    _userSeek(clamped);
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
      _userSeek(Duration(seconds: target.round()));
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
                // Seed focus on the current track so the sheet is operable by
                // remote as soon as it opens.
                autofocus: (track as dynamic).id == selectedId,
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
    return PopScope(
      // Back inside the overlay steps out of the controls rather than leaving
      // playback altogether; a second Back then exits. Without this, reaching
      // for the subtitle button and changing your mind drops you out of the
      // film — a costly mistake with a remote.
      //
      // On a TV, BACK peels one layer per press: a scrub being chosen is
      // cancelled, then visible controls are hidden, then you leave. An error
      // screen leaves at once — there is nothing to peel.
      canPop: _tv
          ? _error != null || (!_controlsVisible && _scrubTarget == null)
          : _keyboardFocus.hasPrimaryFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Now, not in dispose: dispose runs after the exit animation, so the
          // screen underneath would slide in sideways first.
          _landscape?.release();
          return;
        }
        if (_tv) {
          if (_scrubTarget != null) {
            _cancelScrub();
            return;
          }
          _hideTimer?.cancel();
          setState(() => _controlsVisible = false);
        }
        _keyboardFocus.requestFocus();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
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
            if (_buffering && _error == null && !_reconnecting)
              Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
            // Covers the (paused) video while the TV has it, so there is never
            // any doubt about which screen is playing.
            if (_cast.isCasting) _castingView(),
            if (_reconnecting) _reconnectingView(),
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
            if (_zapToast != null)
              Align(
                alignment: const Alignment(0, -0.55),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_zapToast!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body),
                ),
              ),
            if ((_upNextCountdown != null || _upNextEarly) && _next != null)
              _upNextCard(),
            if (_shouldShowNextEpisode()) _nextEpisodeButton(),
            if (_flashIcon != null) _centreFlash(),
            _controlsOverlay(),
            if (_prefs.showPlaybackStats) _statsOverlay(),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// The play/pause glyph that pops up mid-screen and fades; see [_togglePlay].
  Widget _centreFlash() {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_flashCount),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          builder: (context, t, child) => Opacity(
            // In fast, then out slowly.
            opacity: t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85,
            child: Transform.scale(scale: 0.85 + 0.25 * t, child: child),
          ),
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: Icon(_flashIcon, size: 68, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Shown while a dropped stream is being reopened. Deliberately quiet: this
  /// is the state that used to be a full error screen, and most of the time it
  /// resolves itself within a couple of seconds.
  /// Shown while a Chromecast has the stream: this device becomes the remote.
  Widget _castingView() {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(castConnectedIcon, size: 56, color: AppColors.accent),
              const SizedBox(height: 20),
              Text(
                _cast.deviceName == null
                    ? 'Playing on your TV'
                    : 'Playing on ${_cast.deviceName}',
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              const SizedBox(height: 6),
              Text(_current.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary)),
              if (!_current.isLive && _cast.durationSeconds > 0) ...[
                const SizedBox(height: 14),
                Text(
                  '${formatSeconds(_cast.positionSeconds)} / '
                  '${formatSeconds(_cast.durationSeconds)}',
                  style: AppTypography.label,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_current.isLive)
                    FocusHighlight(
                      borderRadius: 24,
                      child: IconButton(
                        iconSize: 32,
                        tooltip: 'Back 10 seconds',
                        onPressed: () => ref
                            .read(castServiceProvider)
                            .seek((_cast.positionSeconds - 10)
                                .clamp(0, 1 << 30)),
                        icon: const Icon(Icons.replay_10),
                      ),
                    ),
                  FocusHighlight(
                    borderRadius: 32,
                    child: IconButton(
                      autofocus: true,
                      iconSize: 46,
                      tooltip: _cast.isPlaying ? 'Pause' : 'Play',
                      onPressed: () {
                        final cast = ref.read(castServiceProvider);
                        _cast.isPlaying ? cast.pause() : cast.play();
                      },
                      icon: Icon(_cast.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                    ),
                  ),
                  if (!_current.isLive)
                    FocusHighlight(
                      borderRadius: 24,
                      child: IconButton(
                        iconSize: 32,
                        tooltip: 'Forward 10 seconds',
                        onPressed: () => ref
                            .read(castServiceProvider)
                            .seek(_cast.positionSeconds + 10),
                        icon: const Icon(Icons.forward_10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FocusHighlight(
                borderRadius: 20,
                child: FilledButton.tonalIcon(
                  onPressed: _stopCasting,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop casting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reconnectingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          // Walking the channel's other streams is not the same event as
          // recovering a dropped one, and saying "Attempt 0 of 3" during a
          // failover was both wrong and alarming. What the viewer needs to
          // know is that something is being tried, never which provider error
          // came back.
          Text(
            _switchingFeed ? 'Switching to backup feed…' : 'Reconnecting…',
            style: AppTypography.body,
          ),
          const SizedBox(height: 4),
          Text(
            _switchingFeed
                ? 'Feed ${_candidateIndex + 1} of ${_candidates.length}'
                : 'Attempt $_reconnectAttempt of $_maxReconnectAttempts',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Turns a raw stream-open failure into a plain-language title + fix hint.
  /// Matches on the combined error text and mpv log tail so it works for the
  /// custom codes IPTV panels use (e.g. 456).
  ({String title, String? hint}) _friendlyError() {
    final blob = '${_error ?? ''}\n${_diagLog.join('\n')}'.toLowerCase();
    bool has(List<String> needles) => needles.any(blob.contains);

    if (has(['456', 'max connection', 'connection limit'])) {
      return (
        title: 'Your provider refused this connection',
        hint: 'This usually means your current IP is blocked, or your '
            "account's connection limit is already in use. Try switching to a "
            'different VPN server, or stop the stream on your other devices, '
            'then Retry.',
      );
    }
    if (has([' 401', ' 403', 'unauthor', 'forbidden', 'denied'])) {
      return (
        title: 'Access denied by your provider',
        hint: 'Your login was rejected. Check that your subscription is active '
            'and your account details are correct.',
      );
    }
    if (has([' 404', 'not found', 'no such'])) {
      return (
        title: "This stream isn't available",
        hint: 'It may be offline or removed. Try a different title or channel.',
      );
    }
    if (has([
      'refused',
      'timed out',
      'timeout',
      'failed host lookup',
      'unreachable',
      'could not reach',
      'tcp:',
      'ffurl_read',
    ])) {
      return (
        title: 'Can’t reach the stream',
        hint: 'Check your internet or VPN connection, then Retry.',
      );
    }
    if (has(['format', 'decode', 'invalid data', 'unsupported', 'codec'])) {
      return (
        title: 'This stream can’t be played',
        hint: 'The format may be unsupported, or the stream is broken. '
            'Try another source.',
      );
    }
    return (title: 'Couldn’t play this stream', hint: null);
  }

  Widget _errorView() {
    // On a TV the cursor goes to Retry as the error appears. OK on the video
    // used to toggle play/pause on a stream that had already failed.
    if (_tv && !_retryFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _error != null &&
            (_keyboardFocus.hasPrimaryFocus || _tvControlsRegion.hasFocus)) {
          _retryFocus.requestFocus();
        }
      });
    }
    final friendly = _friendlyError();
    final hasDetail = _diagLog.isNotEmpty || _error != null;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(friendly.title,
                  textAlign: TextAlign.center, style: AppTypography.title),
            ),
            if (friendly.hint != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(friendly.hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
            const SizedBox(height: 16),
            FocusHighlight(
              borderRadius: 24,
              child: FilledButton.icon(
                focusNode: _retryFocus,
                onPressed: () {
                  // Back to the video before this button disappears, or the
                  // remote is left pointing at nothing once playback resumes.
                  _keyboardFocus.requestFocus();
                  _openCurrent(resumeFrom: _reopenAt());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            if (hasDetail) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    setState(() => _showErrorDetails = !_showErrorDetails),
                child: Text(
                    _showErrorDetails ? 'Hide details' : 'Technical details'),
              ),
              if (_showErrorDetails)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(10),
                  constraints:
                      const BoxConstraints(maxHeight: 160, maxWidth: 640),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      [?_error, ..._diagLog].join('\n'),
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// How close to the end the "Next Episode" button appears.
  static const _nextEpisodeWindow = Duration(seconds: 20);

  /// Netflix/HBO-style: a "Next Episode" button in the last seconds, so the
  /// outro can be skipped even after "Keep watching". Distinct from the
  /// on-completion autoplay countdown, and never shown alongside the up-next
  /// card — the two used to sit in the same spot, one on top of the other.
  bool _shouldShowNextEpisode() {
    if (_next == null || _current.isLive || _upNextCountdown != null) {
      return false;
    }
    if (_upNextEarly || !_endIsKnown) return false;
    final remaining = _duration - _position;
    return remaining > Duration.zero && remaining <= _nextEpisodeWindow;
  }

  /// Where the next-episode prompts sit: bottom right, inside a television's
  /// overscan margin. On a TV the controls are a tall block (title, seek bar,
  /// transport row), so the prompt lifts clear of them while they show — it
  /// used to be drawn underneath them. A phone's controls end in a single seek
  /// row that 96 px already clears.
  Widget _nextPromptSlot({required Widget child}) {
    final tv = isTelevisionOf(ref);
    final bottom = tv ? (_controlsVisible ? 232.0 : 56.0) : 96.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      right: tv ? 48 : 24,
      bottom: bottom,
      child: child,
    );
  }

  Widget _nextEpisodeButton() {
    return _nextPromptSlot(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onUpNextKey,
        child: FocusHighlight(
          borderRadius: 24,
          child: FilledButton.icon(
            focusNode: _upNextFocus,
            onPressed: () => _playNext(fromOffer: true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.skip_next),
            label: const Text('Next Episode'),
          ),
        ),
      ),
    );
  }

  Widget _upNextCard() {
    final next = _next!;
    final tv = isTelevisionOf(ref);
    final early = _upNextCountdown == null;
    return _nextPromptSlot(
      // A width cap rather than a fixed width: the text-size setting scales
      // everything inside, and a fixed 260 px put the second button outside
      // the card at anything above Standard.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tv ? 440 : 320),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Two moments, two cards. Before the end we are guessing where
              // the credits start, so it is an offer with no clock on it. At
              // the end the episode is over and the countdown is right.
              Text(early ? 'Up next' : 'Up next in $_upNextCountdown…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label
                      .copyWith(color: AppColors.accentAlt)),
              const SizedBox(height: 6),
              Text(next.subtitle ?? next.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body),
              const SizedBox(height: 10),
              // Focus is put here explicitly, and only late (see
              // _maybeFocusUpNext): `autofocus` did nothing while the video
              // surface held the cursor, which is always.
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _onUpNextKey,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FocusHighlight(
                      borderRadius: 20,
                      child: FilledButton(
                        focusNode: _upNextFocus,
                        onPressed: () => _playNext(fromOffer: early),
                        child: Text(early ? 'Next episode' : 'Play now',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    FocusHighlight(
                      borderRadius: 20,
                      child: TextButton(
                        onPressed: () {
                          _upNextTimer?.cancel();
                          setState(() {
                            _upNextCountdown = null;
                            _upNextEarly = false;
                          });
                          // The card is going; the cursor must not go with it.
                          _keyboardFocus.requestFocus();
                        },
                        child: Text(early ? 'Keep watching' : 'Cancel',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Settings → Playback stats: what the start cost and what is playing, on
  /// the screen itself, so a slow start on a real TV can be read off (or
  /// photographed) instead of guessed at. Never focusable, never tappable.
  Widget _statsOverlay() {
    final tv = isTelevisionOf(ref);
    final s = _mpvStats;
    String? v(String key) {
      final value = s[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final width = v('video-params/w'), height = v('video-params/h');
    final fps = double.tryParse(v('estimated-vf-fps') ?? '');
    final speed = int.tryParse(v('cache-speed') ?? '');
    final ahead = double.tryParse(v('demuxer-cache-duration') ?? '');
    final dropped = [v('frame-drop-count'), v('decoder-frame-drop-count')]
        .whereType<String>()
        .join(' / ');
    final lines = <String>[
      'START-UP',
      ..._stats.timeline(),
      '',
      'STREAM',
      if (_stats.feed != null) _stats.feed!,
      [
        if (width != null && height != null) '$width×$height',
        ?v('video-codec'),
        if (fps != null) '${fps.toStringAsFixed(1)} fps',
        if (v('hwdec-current') case final hw?) 'hw: $hw',
      ].join(' · '),
      if (v('audio-codec-name') case final audio?) 'audio: $audio',
      '',
      'NETWORK',
      [
        if (speed != null) 'download ${_PlaybackStats.rate(speed)}',
        if (ahead != null) 'buffered ${ahead.toStringAsFixed(1)} s ahead',
      ].join(' · '),
      if (_stats.cacheMode != null) 'cache: ${_stats.cacheMode}',
      'stalls after start: ${_stats.stallSummary()}',
      if (dropped.isNotEmpty) 'dropped frames: $dropped',
      [
        'audio delay: ${(_audioDelaySeconds() * 1000).round()} ms',
        if (v('current-ao') case final ao?) 'out: $ao',
        if (double.tryParse(v('avsync') ?? '') case final avsync?)
          'A-V ${(avsync * 1000).round()} ms',
      ].join(' · '),
    ];
    return Positioned(
      left: tv ? 48 : 16,
      top: tv ? 32 : 72,
      child: IgnorePointer(
        child: ExcludeFocus(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveIndicator() {
    // Behind the live edge the badge stops claiming to be live and says how far
    // back you are, with the way forward next to it. A red LIVE dot over a
    // programme that finished ten minutes ago is a lie the user would have to
    // work out for themselves.
    final behind = _behindLive;
    final live = !_canTimeshift || _atLiveEdge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: live ? AppColors.error : AppColors.textSecondary,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            live ? 'LIVE' : '−${formatSeconds(behind.inSeconds)}',
            style: AppTypography.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: live ? 1.5 : 0.5),
          ),
          if (!live) ...[
            const SizedBox(width: 12),
            FocusHighlight(
              borderRadius: 20,
              child: TextButton.icon(
                onPressed: _goLive,
                icon: const Icon(Icons.fast_forward, size: 18),
                label: const Text('Go live'),
              ),
            ),
          ],
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

  /// The television transport: one cluster at the bottom of the screen.
  ///
  /// Deliberately shaped like Netflix's and HBO's, and for a reason that is
  /// about the remote rather than fashion. The touch layout scatters controls
  /// across three zones — a top bar, a big play button in the middle, a seek bar
  /// at the bottom — which is fine for a thumb and awful for a D-pad: every
  /// up/down press jumps across the whole screen, and the geometry decides where
  /// focus lands. Gathering everything into one bottom cluster makes the moves
  /// short and predictable: UP/DOWN swaps between the scrubber and the button
  /// row, LEFT/RIGHT walks the row, BACK drops you back to the picture.
  ///
  /// There is no on-screen Back button, also on purpose: BACK on the remote
  /// already leaves the controls, and a second press exits.
  Widget _tvControls(
      Duration position, int durationSeconds, double bufferFraction) {
    final queued = widget.request.queue.length > 1;
    final controls = AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Generous side padding: real sets crop the outer few percent.
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_current.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.display.copyWith(fontSize: 24)),
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
                      const SizedBox(height: 14),
                      if (_current.isLive)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: _liveIndicator())
                      else
                        _tvSeekBar(position, durationSeconds, bufferFraction),
                      const SizedBox(height: 6),
                      Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: _onTvRowKey,
                        child: Row(
                          children: [
                            if (queued)
                              _TvControlButton(
                                label: 'Previous episode',
                                icon: Icons.skip_previous_rounded,
                                onPressed: _hasPrevious ? _playPrevious : null,
                              ),
                            if (_canZap)
                              _TvControlButton(
                                label: 'Channel down',
                                icon: Icons.keyboard_arrow_down_rounded,
                                onPressed: () => _zapBy(-1),
                              ),
                            // Live only. A film or episode skips with LEFT/RIGHT
                            // on the scrubber, from the very first press, so a
                            // second way to do it only made the row longer. Live
                            // has no scrubber: these are its rewind, once the
                            // timeshift buffer has something to rewind into.
                            if (_canTimeshift)
                              _TvControlButton(
                                label: 'Back 10 s',
                                icon: Icons.replay_10_rounded,
                                onPressed: () => _seekRelative(-10),
                              ),
                            _TvControlButton(
                              focusNode: _playPauseFocus,
                              label: _playing ? 'Pause' : 'Play',
                              icon: _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              iconSize: 38,
                              onPressed: () {
                                _togglePlay();
                                _scheduleHide();
                              },
                            ),
                            // Forward is disabled at the live edge rather than
                            // hidden, so the row does not reflow as you scrub.
                            if (_canTimeshift)
                              _TvControlButton(
                                label: 'Forward 10 s',
                                icon: Icons.forward_10_rounded,
                                onPressed: _atLiveEdge
                                    ? null
                                    : () => _seekRelative(10),
                              ),
                            if (_canZap)
                              _TvControlButton(
                                label: 'Channel up',
                                icon: Icons.keyboard_arrow_up_rounded,
                                onPressed: () => _zapBy(1),
                              ),
                            if (queued)
                              _TvControlButton(
                                label: 'Next episode',
                                icon: Icons.skip_next_rounded,
                                onPressed: _next != null ? _playNext : null,
                              ),
                            // The rest of the row, pushed to the right. Scaled
                            // down rather than overflowing when a large text size
                            // and a long focused label leave it short of room.
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // On a television you are already on the big
                                      // screen, so casting is only offered when this
                                      // build is NOT the TV one (see _castAvailable,
                                      // which is false there) — this branch keeps the
                                      // row consistent if that ever changes.
                                      if (_castAvailable)
                                        _TvControlButton(
                                          label: castActionLabel,
                                          icon: castIcon,
                                          iconSize: 26,
                                          onPressed: _startCasting,
                                        ),
                                      // Menus name themselves all the time, not only
                                      // under the cursor: they are what a viewer
                                      // goes looking for, by name.
                                      _TvControlButton(
                                        label: 'Audio',
                                        icon: Icons.audiotrack_outlined,
                                        iconSize: 26,
                                        alwaysLabelled: true,
                                        onPressed: _showAudioSheet,
                                      ),
                                      _TvControlButton(
                                        label: 'Subtitles',
                                        icon: Icons.subtitles_outlined,
                                        iconSize: 26,
                                        alwaysLabelled: true,
                                        onPressed: _showSubtitleSheet,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Out of focus traversal while hidden. Fading them out only made them
    // transparent, so the remote could still land on buttons nobody could see.
    return ExcludeFocus(
      excluding: !_controlsVisible,
      child: Focus(focusNode: _tvControlsRegion, child: controls),
    );
  }

  /// Scrubber sized for a ten-foot view.
  ///
  /// Not a Slider. A stock Slider seeks on every key press, in steps of 5% of
  /// the runtime, and in the default navigation mode it takes UP and DOWN as
  /// value changes too — so it could only be left with BACK ("I have to escape
  /// the time bar"). This one shows a target the viewer moves with LEFT/RIGHT
  /// and jumps once, on OK or when the pressing stops; UP/DOWN leave it. See
  /// [_onScrubKey].
  Widget _tvSeekBar(
      Duration position, int durationSeconds, double bufferFraction) {
    final target = _scrubTarget;
    final totalMs = durationSeconds > 0 ? durationSeconds * 1000 : 1;
    double fraction(Duration d) =>
        (d.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        // While choosing, the clock shows where you will land.
        Text(formatSeconds((target ?? position).inSeconds),
            style: target == null
                ? AppTypography.label
                : AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(
          child: FocusHighlight(
            borderRadius: 10,
            scale: 1.0,
            child: Focus(
              focusNode: _scrubFocus,
              onKeyEvent: _onScrubKey,
              child: ListenableBuilder(
                listenable: _scrubFocus,
                builder: (context, _) {
                  final focused = _scrubFocus.hasFocus;
                  final trackHeight = focused ? 8.0 : 5.0;
                  final thumb = focused ? 20.0 : 14.0;
                  return LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final played = fraction(position);
                    Widget bar(double widthFactor, Color color) => Container(
                          width: width * widthFactor,
                          height: trackHeight,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(trackHeight / 2),
                          ),
                        );
                    return SizedBox(
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          bar(1, Colors.white24),
                          bar(bufferFraction, Colors.white38),
                          bar(played, AppColors.accent),
                          if (target != null) ...[
                            // The stretch you are about to skip over (or back
                            // across), so the size of the jump is visible.
                            Positioned(
                              left: width *
                                  (fraction(target) < played
                                      ? fraction(target)
                                      : played),
                              child: bar(
                                  (fraction(target) - played).abs(),
                                  Colors.white70),
                            ),
                            Positioned(
                              left: width * fraction(target) - 2,
                              child: Container(
                                  width: 4, height: 30, color: Colors.white),
                            ),
                            Positioned(
                              top: -30,
                              left: (width * fraction(target) - 60)
                                  .clamp(0.0, (width - 120).clamp(0.0, width)),
                              child: _scrubLabel(target, position),
                            ),
                          ],
                          Positioned(
                            left: width * played - thumb / 2,
                            child: Container(
                              width: thumb,
                              height: thumb,
                              decoration: BoxDecoration(
                                color: focused ? Colors.white : AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(formatSeconds(durationSeconds), style: AppTypography.label),
      ],
    );
  }

  /// "1:23:45 · +2:30" above the scrub marker.
  Widget _scrubLabel(Duration target, Duration position) {
    final delta = target - position;
    final sign = delta.isNegative ? '−' : '+';
    return Container(
      width: 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${formatSeconds(target.inSeconds)} · $sign'
        '${formatSeconds(delta.abs().inSeconds)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13),
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

    if (isTelevisionOf(ref)) {
      return _tvControls(position, durationSeconds, bufferFraction);
    }

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
                    if (_castAvailable)
                      IconButton(
                        tooltip: castActionLabel,
                        onPressed: _startCasting,
                        icon: Icon(castIcon),
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
                    // Previous episode (series queues).
                    if (widget.request.queue.length > 1) ...[
                      IconButton(
                        iconSize: 32,
                        tooltip: 'Previous',
                        onPressed: _hasPrevious ? _playPrevious : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      const SizedBox(width: 16),
                    ],
                    // Live gets channel down/up where VOD gets skip back/
                    // forward: on a channel there is nothing to seek through,
                    // and zapping is what the position is actually used for.
                    if (_canZap) ...[
                      IconButton(
                        iconSize: 40,
                        tooltip: 'Channel down',
                        onPressed: () => _zapBy(-1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      const SizedBox(width: 28),
                    ],
                    // Live gains these once the timeshift buffer has something
                    // to rewind into, so zapping and scrubbing can coexist.
                    if (!_current.isLive || _canTimeshift) ...[
                      IconButton(
                        iconSize: 40,
                        onPressed: () => _seekRelative(-10),
                        icon: const Icon(Icons.replay_10),
                      ),
                      const SizedBox(width: 28),
                    ],
                    IconButton(
                      focusNode: _playPauseFocus,
                      iconSize: 64,
                      onPressed: () {
                        _player.playOrPause();
                        _scheduleHide();
                      },
                      icon: Icon(_playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                    ),
                    if (!_current.isLive || _canTimeshift) ...[
                      const SizedBox(width: 28),
                      IconButton(
                        iconSize: 40,
                        // Disabled rather than hidden at the live edge, so the
                        // row does not reflow while you scrub.
                        onPressed: _current.isLive && _atLiveEdge
                            ? null
                            : () => _seekRelative(10),
                        icon: const Icon(Icons.forward_10),
                      ),
                    ],
                    if (_canZap) ...[
                      const SizedBox(width: 28),
                      IconButton(
                        iconSize: 40,
                        tooltip: 'Channel up',
                        onPressed: () => _zapBy(1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                    ],
                    // Next episode (series queues).
                    if (widget.request.queue.length > 1) ...[
                      const SizedBox(width: 16),
                      IconButton(
                        iconSize: 32,
                        tooltip: 'Next',
                        onPressed: _next != null ? _playNext : null,
                        icon: const Icon(Icons.skip_next),
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
                                  _userSeek(Duration(seconds: v.round()));
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

/// What the stats overlay reports about the current item's start, collected
/// as it happens. One clock per item: a reconnect or a switch to a backup feed
/// is marked on the same clock, so its cost shows in the total.
class _PlaybackStats {
  final _clock = Stopwatch();
  final List<(String, Duration)> _marks = [];

  /// "feed 2 of 3 · backup host 1 · stream 1234", when there is a choice.
  String? feed;

  /// Where mpv keeps its buffer: "memory", or "disk (timeshift)" for live.
  String? cacheMode;

  int _stalls = 0;
  Duration _stalled = Duration.zero;
  DateTime? _stallStarted;

  void start() {
    _marks.clear();
    _stalls = 0;
    _stalled = Duration.zero;
    _stallStarted = null;
    feed = null;
    _clock
      ..reset()
      ..start();
  }

  void mark(String label) {
    if (_clock.isRunning) _marks.add((label, _clock.elapsed));
  }

  /// Buffering that happens AFTER the first frame is a stall; before it, it is
  /// just the start.
  void onBuffering(bool buffering, {required bool afterStart}) {
    if (!afterStart) return;
    if (buffering) {
      if (_stallStarted == null) {
        _stalls++;
        _stallStarted = DateTime.now();
      }
    } else if (_stallStarted != null) {
      _stalled += DateTime.now().difference(_stallStarted!);
      _stallStarted = null;
    }
  }

  /// One line per step: how long it took, and the running total.
  List<String> timeline() {
    var previous = Duration.zero;
    return [
      for (final (label, at) in _marks)
        () {
          final step = at - previous;
          previous = at;
          return '${label.padRight(15)} +${_ms(step).padLeft(7)}'
              '  = ${_ms(at)}';
        }(),
    ];
  }

  String stallSummary() {
    final ongoing = _stallStarted == null
        ? Duration.zero
        : DateTime.now().difference(_stallStarted!);
    return _stalls == 0
        ? 'none'
        : '$_stalls (${((_stalled + ongoing).inMilliseconds / 1000).toStringAsFixed(1)} s)';
  }

  /// The same timeline as a single line for `adb logcat`.
  void logSummary(String title) {
    debugPrint('[dawn] start "$title": '
        '${_marks.map((m) => '${m.$1} ${m.$2.inMilliseconds}ms').join(' · ')}'
        '${feed == null ? '' : ' · $feed'}'
        '${cacheMode == null ? '' : ' · cache $cacheMode'}');
  }

  static String _ms(Duration d) => '${d.inMilliseconds} ms';

  /// mpv's cache-speed (bytes per second) as something readable.
  static String rate(int bytesPerSecond) {
    final mbit = bytesPerSecond * 8 / 1e6;
    return mbit >= 1
        ? '${mbit.toStringAsFixed(1)} Mbit/s'
        : '${(bytesPerSecond * 8 / 1e3).toStringAsFixed(0)} kbit/s';
  }
}

/// A television transport button: an icon that becomes a solid white pill
/// with its NAME in it when the cursor is on it.
///
/// The white pill is what Netflix and HBO do, and for a reason: Material's own
/// focus state is a faint wash that disappears over moving video. The name is
/// the other half — a remote has no hover and a television shows no tooltips,
/// so an icon-only row left the viewer guessing what OK was about to do.
/// [alwaysLabelled] keeps the name showing for actions that open something
/// rather than act on the picture.
class _TvControlButton extends StatefulWidget {
  const _TvControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.iconSize = 30,
    this.alwaysLabelled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final double iconSize;
  final bool alwaysLabelled;

  @override
  State<_TvControlButton> createState() => _TvControlButtonState();
}

class _TvControlButtonState extends State<_TvControlButton> {
  FocusNode? _ownNode;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownNode ??= FocusNode(debugLabel: 'tv-${widget.label}'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_TvControlButton old) {
    super.didUpdateWidget(old);
    final before = old.focusNode ?? _ownNode;
    if (before != _node) {
      before?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = _node.hasFocus;
    final enabled = widget.onPressed != null;
    final showLabel = focused || widget.alwaysLabelled;
    final colour = focused
        ? Colors.black
        : enabled
            ? Colors.white
            : Colors.white38;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        label: widget.label,
        button: true,
        excludeSemantics: true,
        child: TextButton(
          focusNode: _node,
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            backgroundColor: focused ? Colors.white : Colors.transparent,
            foregroundColor: colour,
            disabledForegroundColor: Colors.white38,
            shape: const StadiumBorder(),
            minimumSize: const Size(52, 52),
            padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 16 : 10, vertical: 8),
          ).copyWith(
            // No grey wash on focus — the white pill is the focus state.
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: widget.iconSize, color: colour),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: colour,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
