import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Chromecast on the network.
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    this.description,
    this.connected = false,
  });

  final String id;
  final String name;
  final String? description;
  final bool connected;
}

enum CastState { unavailable, disconnected, connecting, connected, buffering, playing, paused }

/// What the receiver is doing right now.
class CastStatus {
  const CastStatus({
    this.state = CastState.disconnected,
    this.deviceName,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
  });

  final CastState state;
  final String? deviceName;
  final int positionSeconds;
  final int durationSeconds;

  bool get isCasting =>
      state == CastState.connected ||
      state == CastState.buffering ||
      state == CastState.playing ||
      state == CastState.paused;

  bool get isPlaying => state == CastState.playing;
}

/// Thin wrapper over the Android Cast bridge (see CastBridge.kt).
///
/// Android only, by design: on iOS the Cast SDK needs local-network and Bonjour
/// permissions that a sideloaded unsigned build cannot reliably obtain, so
/// [isAvailable] simply answers false there and the UI hides the button rather
/// than offering something that will not work.
class CastService {
  CastService._();

  static final instance = CastService._();

  static const _method = MethodChannel('dawnplayer/cast');
  static const _devices = EventChannel('dawnplayer/cast/devices');
  static const _status = EventChannel('dawnplayer/cast/status');

  Future<bool> isAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isAvailable') ?? false;
    } on Object {
      // No implementation registered (iOS, desktop) — treat as unsupported.
      return false;
    }
  }

  Future<void> startDiscovery() => _invoke('startDiscovery');
  Future<void> stopDiscovery() => _invoke('stopDiscovery');
  Future<void> disconnect() => _invoke('disconnect');
  Future<void> play() => _invoke('play');
  Future<void> pause() => _invoke('pause');
  Future<void> stop() => _invoke('stop');

  Future<void> connect(String deviceId) =>
      _invoke('connect', {'id': deviceId});

  Future<void> seek(int positionSeconds) =>
      _invoke('seek', {'positionSeconds': positionSeconds});

  Future<void> load({
    required String url,
    required String contentType,
    required bool isLive,
    required String title,
    String? subtitle,
    int positionSeconds = 0,
  }) =>
      _invoke('load', {
        'url': url,
        'contentType': contentType,
        'isLive': isLive,
        'title': title,
        'subtitle': subtitle,
        'positionSeconds': positionSeconds,
      });

  Stream<List<CastDevice>> get devices =>
      _devices.receiveBroadcastStream().map((event) {
        final list = (event as List?) ?? const [];
        return [
          for (final item in list.cast<Map<Object?, Object?>>())
            CastDevice(
              id: item['id'] as String,
              name: (item['name'] as String?) ?? 'Chromecast',
              description: item['description'] as String?,
              connected: item['connected'] as bool? ?? false,
            ),
        ];
      });

  Stream<CastStatus> get status =>
      _status.receiveBroadcastStream().map((event) {
        final map = (event as Map?)?.cast<Object?, Object?>() ?? const {};
        return CastStatus(
          state: switch (map['state'] as String?) {
            'playing' => CastState.playing,
            'paused' => CastState.paused,
            'buffering' => CastState.buffering,
            'connected' => CastState.connected,
            _ => CastState.disconnected,
          },
          deviceName: map['deviceName'] as String?,
          positionSeconds: (map['positionSeconds'] as num?)?.toInt() ?? 0,
          durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
        );
      });

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _method.invokeMethod<void>(method, args);
    } on PlatformException {
      rethrow; // The caller shows these; they carry a usable message.
    } on MissingPluginException {
      // Unsupported platform — nothing to do.
    }
  }
}

final castServiceProvider = Provider<CastService>((ref) => CastService.instance);

/// Whether this build/device can cast at all. Drives whether the button exists.
final castAvailableProvider = FutureProvider<bool>(
    (ref) => ref.watch(castServiceProvider).isAvailable());

/// Devices currently visible. Discovery runs only while something is listening,
/// because an active scan is power-hungry.
final castDevicesProvider = StreamProvider.autoDispose<List<CastDevice>>((ref) {
  final service = ref.watch(castServiceProvider);
  service.startDiscovery();
  ref.onDispose(service.stopDiscovery);
  return service.devices;
});

final castStatusProvider = StreamProvider<CastStatus>(
    (ref) => ref.watch(castServiceProvider).status);
