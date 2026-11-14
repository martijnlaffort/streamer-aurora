import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// A file the system handed over: picked in the document picker, or opened in
/// Dawn Player from Files, another app's share sheet or "Open with".
class LocalMediaPick {
  const LocalMediaPick({
    required this.ref,
    required this.name,
    required this.path,
    this.sizeBytes,
  });

  /// What to keep to reach the file again after a restart.
  ///
  /// On iOS a security-scoped bookmark (base64): the path alone stops working
  /// the moment the app quits, because access to a file outside the sandbox is
  /// granted per launch. On Android a `content://` URI whose read permission
  /// has been persisted. Opaque to Dart either way — only [LocalMediaPlatform]
  /// turns it back into something playable.
  final String ref;

  /// The file name as the system reports it, e.g. `Holiday 2024.mkv`.
  final String name;

  /// What to hand the player right now: a file path on iOS, a `content://`
  /// URI on Android. For subtitles and playlists it is a private copy.
  final String path;

  final int? sizeBytes;

  static LocalMediaPick? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final ref = raw['ref'];
    final name = raw['name'];
    final path = raw['path'];
    if (ref is! String || name is! String || path is! String) return null;
    final size = raw['size'];
    return LocalMediaPick(
      ref: ref,
      name: name,
      path: path,
      sizeBytes: size is int ? size : null,
    );
  }
}

/// What arrived from outside the app.
enum OpenedKind { video, playlist }

class OpenedFile {
  const OpenedFile(this.kind, this.pick);

  final OpenedKind kind;
  final LocalMediaPick pick;
}

/// The device's own files: the system document picker, files opened in the app
/// from elsewhere, and re-opening them later.
///
/// Native on both sides (`AppDelegate.swift`'s `LocalMediaBridge`, and
/// `MainActivity.kt`) because the hard part is not picking a file but being
/// allowed to read it again tomorrow: iOS security-scoped bookmarks and
/// Android's persistable URI permissions have no Dart equivalent.
abstract class LocalMediaPlatform {
  /// Whether this device can open its own files at all. False on desktop
  /// builds, which have no bridge.
  bool get isSupported;

  /// The document picker, for one video. Null when cancelled.
  Future<LocalMediaPick?> pickVideo();

  /// The document picker, for one subtitle file (`.srt`, `.ass`, `.ssa`,
  /// `.vtt`). [LocalMediaPick.path] is a private copy, so it outlives the
  /// picker's access.
  Future<LocalMediaPick?> pickSubtitle();

  /// The document picker, for one `.m3u` / `.m3u8` playlist file, copied into
  /// the app's own storage (the playlist is re-read on every refresh).
  Future<LocalMediaPick?> pickPlaylist();

  /// Turns a stored [LocalMediaPick.ref] back into something to hand the
  /// player right now, or null when the file is gone or access was revoked.
  ///
  /// iOS: a path, after a coordinated read, which makes iCloud Drive or a
  /// network share in Files download the file first (this can take a while).
  /// Android: an `fdclose://` URL for a freshly opened descriptor, which mpv
  /// closes when it is done — so call this once per playback, not to check.
  Future<String?> resolve(String ref);

  /// Whether [ref] can still be played, without opening or downloading it.
  /// False for a file shared with the app for one session only, once that
  /// session is over.
  Future<bool> isAvailable(String ref);

  /// Files opened in Dawn Player from outside, including the one that
  /// launched it.
  Stream<OpenedFile> get opened;
}

class MethodChannelLocalMedia implements LocalMediaPlatform {
  MethodChannelLocalMedia();

  static const _methods = MethodChannel('dawnplayer/local_media');
  static const _events = EventChannel('dawnplayer/local_media/opened');

  @override
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Future<LocalMediaPick?> _pick(String kind) async {
    if (!isSupported) return null;
    try {
      return LocalMediaPick.fromMap(
          await _methods.invokeMethod<Object?>('pick', {'kind': kind}));
    } on PlatformException catch (e) {
      debugPrint('[dawn] file picker failed: ${e.code} ${e.message}');
      return null;
    }
  }

  @override
  Future<LocalMediaPick?> pickVideo() => _pick('video');

  @override
  Future<LocalMediaPick?> pickSubtitle() => _pick('subtitle');

  @override
  Future<LocalMediaPick?> pickPlaylist() => _pick('playlist');

  @override
  Future<String?> resolve(String ref) async {
    if (!isSupported) return null;
    try {
      return await _methods.invokeMethod<String>('resolve', {'ref': ref});
    } on PlatformException catch (e) {
      debugPrint('[dawn] could not reopen a local file: ${e.code}');
      return null;
    }
  }

  @override
  Future<bool> isAvailable(String ref) async {
    if (!isSupported) return false;
    try {
      return await _methods.invokeMethod<bool>('isAvailable', {'ref': ref}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  @override
  late final Stream<OpenedFile> opened = !isSupported
      ? const Stream.empty()
      : _events.receiveBroadcastStream().handleError((Object e) {
          debugPrint('[dawn] opened-file stream error: $e');
        }).expand<OpenedFile>((raw) {
          if (raw is! Map) return const [];
          final pick = LocalMediaPick.fromMap(raw);
          if (pick == null) return const [];
          final kind = raw['kind'] == 'playlist'
              ? OpenedKind.playlist
              : OpenedKind.video;
          return [OpenedFile(kind, pick)];
        });
}
