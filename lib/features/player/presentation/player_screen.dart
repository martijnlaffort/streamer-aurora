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
    show Preferences, StreamRef, StreamType, contentKeyFor;
import '../player_request.dart';
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

  /// Grabbed once so dispose-time saving never touches `ref` late.
  late final WatchProgressRepository _progressRepo =
      ref.read(watchProgressRepositoryProvider);

  // Clamped: a caller can hand over a stale or -1 start index (an episode that
  // fell out of a refreshed list), and `queue[_index]` must never RangeError.
  late int _index =
      widget.request.startIndex.clamp(0, widget.request.queue.length - 1);

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

  /// Automatic recovery from a dropped stream.
  ///
  /// IPTV transports drop constantly — a few seconds of bad wifi, a panel
  /// hiccup, a re-negotiated CDN edge. Surfacing the error screen on the first
  /// failure turned every one of those into a manual Retry tap, which on a TV
  /// means finding the remote. We now reopen silently a few times first, and
  /// only fall through to the error screen once it is clear the stream is
  /// genuinely gone.
  static const _maxReconnectAttempts = 3;
  int _reconnectAttempt = 0;
  bool _reconnecting = false;
  Timer? _reconnectTimer;

  /// Set once the current media has actually produced playback, which is what
  /// makes a later failure a *drop* (worth retrying silently) rather than a
  /// stream that never opened at all.
  bool _everPlayed = false;

  /// Focus node for remote/keyboard input. The player is the one screen where
  /// the entire UI is a video surface, so it owns key handling directly rather
  /// than relying on focus traversal between buttons.
  final _keyboardFocus = FocusNode(debugLabel: 'player-keys');

  /// The play/pause button — the entry point when the remote moves off the
  /// video surface into the on-screen controls. Focusing a concrete control is
  /// the only way in: directional traversal from [_keyboardFocus] has no target
  /// because that node's rect is the whole screen.
  final _playPauseFocus = FocusNode(debugLabel: 'player-playpause');

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
    ref.read(playbackActivityProvider).enter();
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
      if (mounted) _prefs = prefs;
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
      setState(() {
        _playing = v;
        if (v) {
          // Playback is live again: clear any recovery state so a *later*
          // unrelated drop gets its own full set of attempts rather than
          // inheriting a used-up budget.
          _everPlayed = true;
          _reconnectAttempt = 0;
          _reconnecting = false;
        }
      });
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
          if (seconds == null || !mounted) return;
          setState(() => _liveEdge =
              Duration(milliseconds: (seconds * 1000).round()));
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
    } catch (_) {
      // Never fatal — playback still works; we just don't own the session.
    }
  }

  @override
  void dispose() {
    _castSub?.cancel();
    ref.read(playbackActivityProvider).leave();
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
    _zapToastTimer?.cancel();
    _keyboardFocus.dispose();
    _playPauseFocus.dispose();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    // Release the session so other apps' audio can resume.
    final session = _audioSession;
    if (session != null) unawaited(session.setActive(false));
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
    final resume = _pendingResumeSeconds;
    if (resume != null && resume < duration.inSeconds) {
      _pendingResumeSeconds = null;
      _player.seek(Duration(seconds: resume));
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
    setState(() {
      _error = null;
      _upNextCountdown = null;
      _liveNow = null;
      // A new stream has a new buffer; keeping the old edge would report a
      // wildly wrong "behind live" until mpv next reported.
      _liveEdge = null;
      _diagLog.clear();
      _showErrorDetails = false;
      if (!isRetry) {
        _reconnectAttempt = 0;
        _reconnecting = false;
        _everPlayed = false;
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
      if (!mounted) return;
      // Present a player User-Agent panels accept (see kStreamUserAgent).
      // Set on the native mpv handle directly — the dedicated `user-agent`
      // property overrides libmpv's default and avoids duplicate headers.
      final platform = _player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('user-agent', kStreamUserAgent);
        await _configureCache(platform, live: _current.isLive);
      }
      await _player.open(Media(url));
      if (!mounted) return;
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
  }

  /// Jump back to the live edge. Deliberately a second short of it — seeking to
  /// the exact end of the buffer lands on data the decoder has not caught up
  /// with and stalls.
  void _goLive() {
    final edge = _liveEdge;
    if (edge == null) return;
    final target = edge - const Duration(seconds: 1);
    _player.seek(target.isNegative ? Duration.zero : target);
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
    final programme =
        await ref.read(epgRepositoryProvider).currentProgramme(account, channel);
    if (mounted) setState(() => _liveNow = programme?.title);
  }

  /// A stream failed. Retry quietly a few times before admitting defeat —
  /// see [_maxReconnectAttempts].
  void _onStreamError(String message) {
    if (!mounted) return;
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
    // Live has no meaningful resume point; VOD picks up where it stopped.
    final resumeFrom = _current.isLive ? null : _position.inSeconds;
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

  bool get _hasPrevious => _index > 0;

  void _playNext() {
    if (_next == null) return;
    // Manual skip: save where we left the current item first (PRD §8.9).
    _saveProgress();
    _upNextTimer?.cancel();
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
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _playing && _error == null) {
        setState(() => _controlsVisible = false);
        // If the remote was parked on a control, hand it back to the video
        // surface as the controls fade — otherwise left/right would keep
        // driving a button that is no longer visible instead of scrubbing.
        if (!_keyboardFocus.hasPrimaryFocus) _keyboardFocus.requestFocus();
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
    try {
      final account = await ref.read(activeAccountProvider.future);
      if (!mounted || account == null) return;
      final catalog = ref.read(catalogRepositoryProvider);
      final total = await catalog.channelCount(
        account,
        categoryId: zap.categoryId,
        categoryIds: zap.categoryIds,
      );
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
      );
      if (channel == null || !mounted) return;
      _saveProgress();
      _reconnectTimer?.cancel();
      setState(() {
        _zap = zap.withIndex(nextIndex);
        _zappedItem = PlayerItem(
          streamRef: StreamRef(
            accountId: channel.accountId,
            type: StreamType.live,
            streamId: channel.id,
          ),
          title: channel.name,
          contentKey: contentKeyFor(
              accountId: channel.accountId,
              type: StreamType.live,
              id: channel.id),
          isLive: true,
        );
      });
      _showZapToast('${nextIndex + 1}/$total · ${channel.name}');
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

  /// Remote and keyboard input.
  ///
  /// Handled here at the top of the player rather than by focus traversal
  /// between the overlay's buttons: a video player's primary controls are the
  /// directional pad itself (left/right scrubs, centre pauses), not a set of
  /// widgets you tab through. Up/Down are deliberately left unhandled so
  /// traversal can still reach the top bar's audio/subtitle/lock buttons.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // Key events bubble up from whatever descendant holds focus. Once the user
    // has moved into the overlay's buttons, the arrows belong to focus
    // traversal — hijacking them here would make the buttons unreachable, since
    // moving between them IS left/right.
    if (!_keyboardFocus.hasPrimaryFocus) {
      _wake();
      // OK/centre activates the focused control. D-pad centre arrives as
      // `select` on many televisions, which is NOT in Flutter's default
      // activation shortcuts, so trigger the focused control ourselves.
      // Everything else (arrows) falls through to traversal and to the focused
      // widget — the seek slider scrubs with left/right, buttons move focus.
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.gameButtonA) {
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

    // Play/pause — the remote's dedicated keys plus the D-pad centre.
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
      _wake();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _player.play();
      _wake();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _player.pause();
      _wake();
      return KeyEventResult.handled;
    }

    // Scrubbing. On a live stream there is nothing to seek through, so the
    // keys only wake the overlay rather than appearing to do nothing.
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      // Live can be scrubbed too now, as far back as the timeshift buffer goes.
      if (!_current.isLive || _canTimeshift) {
        _seekRelative(-10);
      } else {
        _wake();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
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

    // Episode queue.
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      if (_next != null) _playNext();
      _wake();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (_hasPrevious) _playPrevious();
      _wake();
      return KeyEventResult.handled;
    }

    // Channel up/down. The remote's dedicated channel keys always zap; the
    // D-pad's up/down only do so while watching live, where changing channel
    // is the thing you actually want them for. Everywhere else they are handed
    // on to focus traversal so the top bar stays reachable.
    if (key == LogicalKeyboardKey.channelUp) {
      if (_canZap) unawaited(_zapBy(1));
      _wake();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.channelDown) {
      if (_canZap) unawaited(_zapBy(-1));
      _wake();
      return KeyEventResult.handled;
    }
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
        _player.seek(Duration(seconds: resumeAt));
      }
      _player.play();
    }
  }

  /// Hand the current stream to a Chromecast.
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

    // Decided in one place, because "can this be cast?" is entirely a question
    // about the container — see castTargetFor.
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
    if (picked != true) {
      // Backed out — carry on watching here.
      if (!_cast.isCasting) await _player.play();
      return;
    }

    try {
      await ref.read(castServiceProvider).load(
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
      canPop: _keyboardFocus.hasPrimaryFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _keyboardFocus.requestFocus();
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
              const Center(
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
            if (_upNextCountdown != null && _next != null) _upNextCard(),
            if (_shouldShowNextEpisode()) _nextEpisodeButton(),
            _controlsOverlay(),
          ],
        ),
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
              const Icon(Icons.cast_connected,
                  size: 56, color: AppColors.accent),
              const SizedBox(height: 20),
              Text(
                _cast.deviceName == null
                    ? 'Casting'
                    : 'Casting to ${_cast.deviceName}',
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              const SizedBox(height: 6),
              Text(_current.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary)),
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
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text(
            'Reconnecting…',
            style: AppTypography.body,
          ),
          const SizedBox(height: 4),
          Text(
            'Attempt $_reconnectAttempt of $_maxReconnectAttempts',
            style: const TextStyle(
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
    final friendly = _friendlyError();
    final hasDetail = _diagLog.isNotEmpty || _error != null;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
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
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openCurrent(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
                      style: const TextStyle(
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

  /// Netflix/HBO-style: a "Next Episode" button appears near the end of an
  /// episode (once past halfway, so short clips don't trigger it early) so you
  /// can skip the outro. Distinct from the on-completion autoplay countdown.
  bool _shouldShowNextEpisode() {
    if (_next == null || _current.isLive || _upNextCountdown != null) {
      return false;
    }
    if (_duration <= Duration.zero) return false;
    final remaining = _duration - _position;
    return remaining > Duration.zero &&
        remaining <= _nextEpisodeWindow &&
        _position > _duration * 0.5;
  }

  Widget _nextEpisodeButton() {
    return Positioned(
      right: 24,
      bottom: 96,
      child: FilledButton.icon(
        onPressed: _playNext,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        icon: const Icon(Icons.skip_next),
        label: const Text('Next Episode'),
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

  /// Focus styling for the television transport.
  ///
  /// A focused control becomes a solid white pill with a dark glyph. This is
  /// what Netflix and HBO both do, and the reason is not decoration: Material's
  /// default focus state is a faint translucent wash, which over moving video on
  /// a big panel is genuinely invisible — "I can't tell where my cursor is" was
  /// the exact complaint. Inverting the control is impossible to miss from a
  /// sofa, whatever frame is behind it.
  ButtonStyle get _tvTransportStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.focused) ? Colors.white : null),
        iconColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.focused) ? Colors.black : null),
        // Returning null for every other state deliberately falls through to
        // the Material defaults, so the ripple and hover feel are untouched.
        overlayColor: WidgetStateProperty.resolveWith((states) => null),
      );

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
    return AnimatedOpacity(
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
                      Row(
                        children: [
                          if (queued)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Previous episode',
                              onPressed: _hasPrevious ? _playPrevious : null,
                              icon: const Icon(Icons.skip_previous),
                            ),
                          if (_canZap)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Channel down',
                              onPressed: () => _zapBy(-1),
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                          // Seeking is offered for VOD always, and for live once
                          // the timeshift buffer has something to rewind into —
                          // so a channel can have both zapping and scrubbing.
                          if (!_current.isLive || _canTimeshift)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Back 10 seconds',
                              onPressed: () => _seekRelative(-10),
                              icon: const Icon(Icons.replay_10),
                            ),
                          IconButton(
                            focusNode: _playPauseFocus,
                            style: _tvTransportStyle,
                            iconSize: 38,
                            tooltip: _playing ? 'Pause' : 'Play',
                            onPressed: () {
                              _player.playOrPause();
                              _scheduleHide();
                            },
                            icon: Icon(_playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                          ),
                          // Forward is disabled at the live edge rather than
                          // hidden, so the row does not reflow as you scrub.
                          if (!_current.isLive || _canTimeshift)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Forward 10 seconds',
                              onPressed: _current.isLive && _atLiveEdge
                                  ? null
                                  : () => _seekRelative(10),
                              icon: const Icon(Icons.forward_10),
                            ),
                          if (_canZap)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Channel up',
                              onPressed: () => _zapBy(1),
                              icon: const Icon(Icons.keyboard_arrow_up),
                            ),
                          if (queued)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 30,
                              tooltip: 'Next episode',
                              onPressed: _next != null ? _playNext : null,
                              icon: const Icon(Icons.skip_next),
                            ),
                          const Spacer(),
                          // On a television you are already on the big screen,
                          // so casting is only offered when this build is NOT
                          // the TV one (see _castAvailable, which is false
                          // there) — this branch keeps the row consistent if
                          // that ever changes.
                          if (_castAvailable)
                            IconButton(
                              style: _tvTransportStyle,
                              iconSize: 26,
                              tooltip: 'Cast to a TV',
                              onPressed: _startCasting,
                              icon: const Icon(Icons.cast),
                            ),
                          IconButton(
                            style: _tvTransportStyle,
                            iconSize: 26,
                            tooltip: 'Audio',
                            onPressed: _showAudioSheet,
                            icon: const Icon(Icons.audiotrack_outlined),
                          ),
                          IconButton(
                            style: _tvTransportStyle,
                            iconSize: 26,
                            tooltip: 'Subtitles',
                            onPressed: _showSubtitleSheet,
                            icon: const Icon(Icons.subtitles_outlined),
                          ),
                        ],
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
  }

  /// Scrubber sized for a ten-foot view, and focusable: once the remote is on
  /// it, LEFT/RIGHT scrub instead of walking the button row.
  Widget _tvSeekBar(
      Duration position, int durationSeconds, double bufferFraction) {
    return Row(
      children: [
        Text(formatSeconds(position.inSeconds), style: AppTypography.label),
        const SizedBox(width: 12),
        Expanded(
          child: FocusHighlight(
            borderRadius: 8,
            scale: 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: LinearProgressIndicator(
                    value: bufferFraction,
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    color: Colors.white38,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.transparent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: durationSeconds > 0
                        ? position.inSeconds.clamp(0, durationSeconds).toDouble()
                        : 0,
                    max: durationSeconds > 0 ? durationSeconds.toDouble() : 1,
                    onChanged: durationSeconds > 0
                        ? (v) => setState(() => _dragSeekSeconds = v)
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
        ),
        const SizedBox(width: 12),
        Text(formatSeconds(durationSeconds), style: AppTypography.label),
      ],
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
                        tooltip: 'Cast to a TV',
                        onPressed: _startCasting,
                        icon: const Icon(Icons.cast),
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
