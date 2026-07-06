// Minimal media_kit iOS smoke-test.
//
// Goals validated by this one screen:
//   1. media_kit (libmpv) compiles for iOS and plays an IPTV stream.
//   2. Audio + subtitle tracks enumerate and can be switched at runtime.
//   3. Errors are legible ON THE DEVICE, not just in logs.
//
// Reference sketch in the task was reconciled against the installed API:
//   media_kit ^1.2.6 / media_kit_video ^2.0.1.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// --- Build stamp (logged on launch) ------------------------------------------
// There is no reliable runtime API for the Flutter SDK version, so we stamp the
// versions we built against. The authoritative Flutter version is whatever the
// CI logs via `flutter --version`; keep these in sync with pubspec.yaml.
const String kMediaKitVersion = 'media_kit ^1.2.6 / media_kit_video ^2.0.1';
const String kFlutterChannel = 'stable (see CI `flutter --version` for exact)';
const String kIosDeploymentTarget = '13.0';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  debugPrint('=== streamer-aurora smoke test ===');
  debugPrint('Flutter channel : $kFlutterChannel');
  debugPrint('media_kit       : $kMediaKitVersion');
  debugPrint('iOS min target  : $kIosDeploymentTarget');

  runApp(const SmokeTestApp());
}

class SmokeTestApp extends StatelessWidget {
  const SmokeTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'media_kit smoke test',
      home: PlayerScreen(),
    );
  }
}

enum PlayerPhase { idle, opening, buffering, playing, error }

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  final TextEditingController _urlController = TextEditingController(
    text: 'http://example.com/live/user/pass/12345.ts',
  );

  final List<StreamSubscription<dynamic>> _subs = [];

  PlayerPhase _phase = PlayerPhase.idle;
  String? _error;

  List<AudioTrack> _audioTracks = const [];
  List<SubtitleTrack> _subtitleTracks = const [];

  // Currently selected track ids (from player.stream.track).
  String? _selectedAudioId;
  String? _selectedSubtitleId;

  @override
  void initState() {
    super.initState();

    _subs.add(_player.stream.tracks.listen((Tracks tracks) {
      setState(() {
        _audioTracks = tracks.audio;
        _subtitleTracks = tracks.subtitle;
      });
    }));

    _subs.add(_player.stream.track.listen((Track track) {
      setState(() {
        _selectedAudioId = track.audio.id;
        _selectedSubtitleId = track.subtitle.id;
      });
    }));

    _subs.add(_player.stream.buffering.listen((bool buffering) {
      setState(() {
        if (_phase == PlayerPhase.error) return;
        _phase = buffering ? PlayerPhase.buffering : PlayerPhase.playing;
      });
    }));

    _subs.add(_player.stream.playing.listen((bool playing) {
      setState(() {
        if (_phase == PlayerPhase.error) return;
        if (playing) _phase = PlayerPhase.playing;
      });
    }));

    _subs.add(_player.stream.error.listen((String error) {
      debugPrint('media_kit error: $error');
      setState(() {
        _phase = PlayerPhase.error;
        _error = error;
      });
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _urlController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _phase = PlayerPhase.opening;
      _error = null;
      _audioTracks = const [];
      _subtitleTracks = const [];
      _selectedAudioId = null;
      _selectedSubtitleId = null;
    });

    try {
      await _player.open(Media(url));
    } catch (e) {
      setState(() {
        _phase = PlayerPhase.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectAudio(AudioTrack track) async {
    try {
      await _player.setAudioTrack(track);
    } catch (e) {
      setState(() => _error = 'setAudioTrack failed: $e');
    }
  }

  Future<void> _selectSubtitle(SubtitleTrack track) async {
    try {
      await _player.setSubtitleTrack(track);
    } catch (e) {
      setState(() => _error = 'setSubtitleTrack failed: $e');
    }
  }

  // --- UI --------------------------------------------------------------------

  String get _phaseLabel {
    switch (_phase) {
      case PlayerPhase.idle:
        return 'idle';
      case PlayerPhase.opening:
        return 'opening…';
      case PlayerPhase.buffering:
        return 'buffering';
      case PlayerPhase.playing:
        return 'playing';
      case PlayerPhase.error:
        return 'error';
    }
  }

  Color get _phaseColor {
    switch (_phase) {
      case PlayerPhase.playing:
        return Colors.green;
      case PlayerPhase.error:
        return Colors.red;
      case PlayerPhase.buffering:
      case PlayerPhase.opening:
        return Colors.orange;
      case PlayerPhase.idle:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('media_kit smoke test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextField(
              controller: _urlController,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Stream URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _play,
                  child: const Text('Play'),
                ),
                const SizedBox(width: 12),
                Text('State: '),
                Text(
                  _phaseLabel,
                  style: TextStyle(
                    color: _phaseColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Video surface.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Video(controller: _controller),
              ),
            ),

            // Error text — must be legible on the device.
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFFFEBEE),
                child: Text(
                  'ERROR: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Audio tracks',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_audioTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('(none detected yet)'),
              )
            else
              ..._audioTracks.map((t) => _trackRow(
                    label: _describeTrack(t.id, t.language, t.title),
                    selected: t.id == _selectedAudioId,
                    onTap: () => _selectAudio(t),
                  )),

            const SizedBox(height: 16),
            const Text('Subtitle tracks',
                style: TextStyle(fontWeight: FontWeight.bold)),
            // Explicit "Off" option.
            _trackRow(
              label: 'Subtitles: Off',
              selected: _selectedSubtitleId == SubtitleTrack.no().id,
              onTap: () => _selectSubtitle(SubtitleTrack.no()),
            ),
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('(none detected yet)'),
              )
            else
              ..._subtitleTracks.map((t) => _trackRow(
                    label: _describeTrack(t.id, t.language, t.title),
                    selected: t.id == _selectedSubtitleId,
                    onTap: () => _selectSubtitle(t),
                  )),
          ],
        ),
      ),
    );
  }

  String _describeTrack(String id, String? language, String? title) {
    final parts = <String>['id=$id'];
    if (language != null && language.isNotEmpty) parts.add('lang=$language');
    if (title != null && title.isNotEmpty) parts.add('title=$title');
    return parts.join('  ·  ');
  }

  Widget _trackRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F2FD) : null,
          border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
