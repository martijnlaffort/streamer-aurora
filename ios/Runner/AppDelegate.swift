import AVFoundation
import AVKit
import Flutter
import GoogleCast
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kept alive for the life of the app; see [CastBridge].
  private var cast: CastBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The stock Default Media Receiver, the same one Android uses. Discovery is
    // NOT started here: the SDK waits for a first cast-button tap by default,
    // and we start it only while the device picker is open, so the
    // local-network permission prompt appears when someone asks to cast rather
    // than at first launch.
    let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
    let options = GCKCastOptions(discoveryCriteria: criteria)
    options.physicalVolumeButtonsWillControlDeviceVolume = true
    GCKCastContext.setSharedInstanceWith(options)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DawnCast") {
      cast = CastBridge(messenger: registrar.messenger())
    }
  }
}

/// Holds one Flutter event sink.
final class EventSinkHolder: NSObject, FlutterStreamHandler {
  var sink: FlutterEventSink?

  /// Called with the new sink whenever Dart starts listening.
  var listened: ((FlutterEventSink) -> Void)?

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    listened?(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}

/// Casting on iPhone: Chromecast AND AirPlay, over the same channels as the
/// Android bridge (`dawnplayer/cast`, `…/devices`, `…/status`), so the Flutter
/// casting view, mini bar and remote work unchanged.
///
/// Chromecasts come from the Google Cast SDK and are listed in the Flutter
/// picker exactly as on Android. AirPlay devices cannot be listed — iOS offers
/// no API for it — so the picker shows one "AirPlay" row, and `airplay` opens
/// Apple's own route picker.
///
/// Transport commands (play, pause, seek, stop) go to whichever one is playing.
final class CastBridge: NSObject {
  private let methods: FlutterMethodChannel
  private let devicesChannel: FlutterEventChannel
  private let statusChannel: FlutterEventChannel
  private let devicesSink = EventSinkHolder()
  private let statusSink = EventSinkHolder()

  private lazy var airPlay = AirPlayController { [weak self] payload in
    self?.publish(payload)
  }
  private lazy var chromecast = ChromecastController(
    onDevices: { [weak self] devices in self?.devicesSink.sink?(devices) },
    onStatus: { [weak self] payload in self?.publish(payload) })

  init(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "dawnplayer/cast", binaryMessenger: messenger)
    devicesChannel = FlutterEventChannel(
      name: "dawnplayer/cast/devices", binaryMessenger: messenger)
    statusChannel = FlutterEventChannel(
      name: "dawnplayer/cast/status", binaryMessenger: messenger)
    super.init()
    devicesSink.listened = { [weak self] sink in
      sink(self?.chromecast.devicePayload() ?? [Any]())
    }
    statusSink.listened = { [weak self] _ in self?.publishCurrent() }
    devicesChannel.setStreamHandler(devicesSink)
    statusChannel.setStreamHandler(statusSink)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func publish(_ payload: [String: Any]) {
    statusSink.sink?(payload)
  }

  private func publishCurrent() {
    if airPlay.isActive {
      publish(airPlay.statusPayload())
    } else {
      publish(chromecast.statusPayload())
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let url = (args["url"] as? String).flatMap({ URL(string: $0) })
    let seconds = (args["positionSeconds"] as? NSNumber)?.doubleValue ?? 0
    let isLive = args["isLive"] as? Bool ?? false
    switch call.method {
    case "isAvailable":
      // AirPlay is always there; Chromecasts are found when the picker opens.
      result(true)
    case "startDiscovery":
      chromecast.startDiscovery()
      result(nil)
    case "stopDiscovery":
      chromecast.stopDiscovery()
      result(nil)
    case "connect":
      guard let id = args["id"] as? String, chromecast.connect(deviceId: id) else {
        result(
          FlutterError(
            code: "no_device", message: "That device is no longer visible.", details: nil))
        return
      }
      if airPlay.isActive { airPlay.end() }
      result(nil)
    case "load":
      guard let url = url else {
        result(FlutterError(code: "bad_args", message: "A url is required.", details: nil))
        return
      }
      chromecast.load(
        url: url,
        contentType: args["contentType"] as? String ?? "video/mp4",
        isLive: isLive,
        title: args["title"] as? String,
        subtitle: args["subtitle"] as? String,
        position: seconds)
      result(nil)
    case "airplay":
      guard let url = url else {
        result(FlutterError(code: "bad_args", message: "A url is required.", details: nil))
        return
      }
      if chromecast.isActive { chromecast.disconnect() }
      airPlay.prepare(url: url, live: isLive, position: seconds, result: result)
    case "play":
      if airPlay.isActive { airPlay.play() } else { chromecast.play() }
      result(nil)
    case "pause":
      if airPlay.isActive { airPlay.pause() } else { chromecast.pause() }
      result(nil)
    case "seek":
      if airPlay.isActive { airPlay.seek(to: seconds) } else { chromecast.seek(to: seconds) }
      result(nil)
    case "stop":
      if airPlay.isActive { airPlay.end() } else { chromecast.stop() }
      result(nil)
    case "disconnect":
      if airPlay.isActive { airPlay.end() }
      chromecast.disconnect()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - AirPlay

/// Sends a stream to an AirPlay device with an AVPlayer — not by mirroring.
///
/// libmpv has no AirPlay, and mirroring puts the phone's whole screen on the
/// TV and runs the video through the phone twice. An AVPlayer with external
/// playback hands the URL to the Apple TV, which fetches and decodes it itself —
/// the same model as a Chromecast. Like the stock Cast receiver it plays HLS and
/// MP4/MOV, not raw MPEG-TS or MKV; the Dart side (castTargetFor) decides what
/// to send, and asks the panel for HLS for live channels.
final class AirPlayController: NSObject, AVRoutePickerViewDelegate {
  private let onStatus: ([String: Any]) -> Void

  private var player: AVPlayer?

  /// A near-invisible view holding an AVPlayerLayer. Without a layer attached,
  /// AirPlay can treat the player as audio-only and send just the sound.
  private var layerHost: UIView?
  private var picker: AVRoutePickerView?

  /// The Dart `airplay` call, answered once a device is chosen or not.
  private var pendingResult: FlutterResult?
  private var startSeconds: Double = 0
  private var isLive = false

  /// Playback has begun on an AirPlay device for the current stream.
  private(set) var isActive = false
  private var externalObservation: NSKeyValueObservation?
  private var statusTimer: Timer?

  init(onStatus: @escaping ([String: Any]) -> Void) {
    self.onStatus = onStatus
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChanged(_:)),
      name: AVAudioSession.routeChangeNotification, object: nil)
  }

  /// Answers [result] true once [url] plays on a device, false when Apple's
  /// picker was closed without choosing one. Already on a device: swaps the
  /// stream there.
  func prepare(url: URL, live: Bool, position: Double, result: @escaping FlutterResult) {
    if isActive, let player = player {
      isLive = live
      player.replaceCurrentItem(with: AVPlayerItem(url: url))
      begin(at: position)
      result(true)
      return
    }
    teardown()
    let player = AVPlayer(playerItem: AVPlayerItem(url: url))
    player.allowsExternalPlayback = true
    player.usesExternalPlaybackWhileExternalScreenIsActive = true
    self.player = player
    isLive = live
    startSeconds = position
    attachLayer(to: player)
    externalObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) {
      [weak self] observed, _ in
      let active = observed.isExternalPlaybackActive
      DispatchQueue.main.async { self?.externalPlaybackChanged(active) }
    }
    pendingResult = result
    // Already routed to an AirPlay device (chosen in Control Center): start there.
    if airPlayRoute() != nil {
      begin(at: position)
      return
    }
    showPicker()
  }

  func play() {
    player?.play()
    onStatus(statusPayload())
  }

  func pause() {
    player?.pause()
    onStatus(statusPayload())
  }

  func seek(to seconds: Double) {
    player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
  }

  /// Stops on the device and tells Dart where it got to, so the phone can
  /// carry on from there.
  func end() {
    let position = player?.currentTime().seconds ?? 0
    player?.pause()
    onStatus(statusPayload(disconnectedAt: position))
    teardown()
  }

  private func begin(at seconds: Double) {
    guard let player = player else { return }
    if !isLive && seconds > 0 {
      player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
    player.play()
    isActive = true
    finishPending(true)
    statusTimer?.invalidate()
    statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.onStatus(self.statusPayload())
    }
    onStatus(statusPayload())
  }

  private func finishPending(_ value: Bool) {
    pendingResult?(value)
    pendingResult = nil
  }

  // Apple's route picker. It is a button; pressing it in code opens the same
  // list the system shows.

  private func showPicker() {
    guard let window = keyWindow() else {
      finishPending(false)
      teardown()
      return
    }
    let picker = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    picker.prioritizesVideoDevices = true
    picker.delegate = self
    picker.alpha = 0.01
    window.addSubview(picker)
    self.picker = picker
    // On the next run-loop turn, once it is laid out.
    DispatchQueue.main.async {
      let button = picker.subviews.compactMap { $0 as? UIButton }.first
      if let button = button {
        button.sendActions(for: .touchUpInside)
      } else {
        self.finishPending(false)
        self.teardown()
      }
    }
  }

  func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
    // Choosing a device takes a moment to become the route. Closed without a
    // choice, it never does: hand playback back to the phone.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self = self, self.pendingResult != nil, !self.isActive else { return }
      self.finishPending(false)
      self.teardown()
    }
  }

  @objc private func routeChanged(_ notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.player != nil else { return }
      if self.airPlayRoute() != nil {
        if !self.isActive { self.begin(at: self.startSeconds) }
      } else if self.isActive && !(self.player?.isExternalPlaybackActive ?? false) {
        // Switched back to the phone from Control Center.
        self.end()
      }
    }
  }

  private func externalPlaybackChanged(_ active: Bool) {
    if active {
      if !isActive { begin(at: startSeconds) }
    } else if isActive && airPlayRoute() == nil {
      end()
    }
  }

  private func airPlayRoute() -> AVAudioSessionPortDescription? {
    AVAudioSession.sharedInstance().currentRoute.outputs.first { $0.portType == .airPlay }
  }

  private func teardown() {
    statusTimer?.invalidate()
    statusTimer = nil
    externalObservation?.invalidate()
    externalObservation = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    layerHost?.removeFromSuperview()
    layerHost = nil
    picker?.removeFromSuperview()
    picker = nil
    isActive = false
    finishPending(false)
  }

  func statusPayload(disconnectedAt: Double? = nil) -> [String: Any] {
    var state = "disconnected"
    if disconnectedAt == nil, isActive, let player = player {
      switch player.timeControlStatus {
      case .playing: state = "playing"
      case .paused: state = "paused"
      case .waitingToPlayAtSpecifiedRate: state = "buffering"
      @unknown default: state = "connected"
      }
    }
    let position = disconnectedAt ?? player?.currentTime().seconds ?? 0
    let duration = isLive ? 0 : (player?.currentItem?.duration.seconds ?? 0)
    let deviceName: Any
    if let name = airPlayRoute()?.portName {
      deviceName = name
    } else if isActive {
      deviceName = "AirPlay"
    } else {
      deviceName = NSNull()
    }
    let payload: [String: Any] = [
      "state": state,
      "kind": "airplay",
      "deviceName": deviceName,
      "positionSeconds": wholeSeconds(position),
      "durationSeconds": wholeSeconds(duration),
    ]
    return payload
  }

  private func attachLayer(to player: AVPlayer) {
    guard let window = keyWindow() else { return }
    let host = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    host.alpha = 0.01
    host.isUserInteractionEnabled = false
    let layer = AVPlayerLayer(player: player)
    layer.frame = host.bounds
    host.layer.addSublayer(layer)
    window.addSubview(host)
    layerHost = host
  }
}

// MARK: - Chromecast

/// Chromecast through the Google Cast SDK, mirroring the Android bridge
/// (CastBridge.kt): discovery while the picker is open, one session, the stock
/// Default Media Receiver. No Cast SDK widgets — the picker is Flutter.
final class ChromecastController: NSObject, GCKDiscoveryManagerListener,
  GCKSessionManagerListener, GCKRemoteMediaClientListener
{
  private let onDevices: ([Any]) -> Void
  private let onStatus: ([String: Any]) -> Void

  /// Devices published to Dart, by the id it sends back to connect.
  private var devices: [String: GCKDevice] = [:]

  /// A load that arrived before the session it needs had started: Dart sends
  /// `load` straight after `connect`, and the session only exists a moment
  /// later.
  private var pendingLoad: (() -> Void)?
  private var listening = false

  init(
    onDevices: @escaping ([Any]) -> Void, onStatus: @escaping ([String: Any]) -> Void
  ) {
    self.onDevices = onDevices
    self.onStatus = onStatus
    super.init()
    GCKCastContext.sharedInstance().sessionManager.add(self)
  }

  private var context: GCKCastContext { GCKCastContext.sharedInstance() }

  private var session: GCKCastSession? { context.sessionManager.currentCastSession }

  private var client: GCKRemoteMediaClient? { session?.remoteMediaClient }

  var isActive: Bool { session != nil }

  // Discovery

  func startDiscovery() {
    let manager = context.discoveryManager
    if !listening {
      manager.add(self)
      listening = true
    }
    manager.startDiscovery()
    onDevices(devicePayload())
  }

  func stopDiscovery() {
    let manager = context.discoveryManager
    manager.stopDiscovery()
    if listening {
      manager.remove(self)
      listening = false
    }
  }

  func devicePayload() -> [Any] {
    let manager = context.discoveryManager
    let connectedId = session?.device.deviceID
    var list: [Any] = []
    devices.removeAll()
    var index: UInt = 0
    while index < manager.deviceCount {
      let device = manager.device(at: index)
      devices[device.deviceID] = device
      let entry: [String: Any] = [
        "id": device.deviceID,
        "name": device.friendlyName ?? "Chromecast",
        "description": device.modelName ?? NSNull(),
        "connected": device.deviceID == connectedId,
      ]
      list.append(entry)
      index += 1
    }
    return list
  }

  func didUpdateDeviceList() {
    onDevices(devicePayload())
  }

  // Session

  func connect(deviceId: String) -> Bool {
    guard let device = devices[deviceId] else { return false }
    return context.sessionManager.startSession(with: device)
  }

  func disconnect() {
    pendingLoad = nil
    // `true` stops the receiver app, so the TV drops back to its own home
    // screen rather than sitting on a paused Dawn Player.
    context.sessionManager.endSessionAndStopCasting(true)
  }

  func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
    session.remoteMediaClient?.add(self)
    let load = pendingLoad
    pendingLoad = nil
    load?()
    onDevices(devicePayload())
    onStatus(statusPayload())
  }

  func sessionManager(
    _ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession
  ) {
    session.remoteMediaClient?.add(self)
    onStatus(statusPayload())
  }

  func sessionManager(
    _ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?
  ) {
    session.remoteMediaClient?.remove(self)
    onDevices(devicePayload())
    onStatus(disconnectedPayload())
  }

  func sessionManager(
    _ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession,
    withError error: Error
  ) {
    pendingLoad = nil
    onDevices(devicePayload())
    onStatus(disconnectedPayload())
  }

  // Media

  func load(
    url: URL, contentType: String, isLive: Bool, title: String?, subtitle: String?,
    position: Double
  ) {
    let send: () -> Void = { [weak self] in
      guard let self = self, let client = self.client else { return }
      let metadata = GCKMediaMetadata(metadataType: isLive ? .generic : .movie)
      if let title = title { metadata.setString(title, forKey: kGCKMetadataKeyTitle) }
      if let subtitle = subtitle {
        metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
      }
      let info = GCKMediaInformationBuilder(contentURL: url)
      info.streamType = isLive ? .live : .buffered
      info.contentType = contentType
      info.metadata = metadata
      let request = GCKMediaLoadRequestDataBuilder()
      request.mediaInformation = info.build()
      request.autoplay = NSNumber(value: true)
      request.startTime = isLive ? 0 : position
      client.add(self)
      client.loadMedia(with: request.build())
    }
    if client != nil {
      send()
    } else {
      pendingLoad = send
    }
  }

  func play() { client?.play() }

  func pause() { client?.pause() }

  func stop() { client?.stop() }

  func seek(to seconds: Double) {
    let options = GCKMediaSeekOptions()
    options.interval = seconds
    client?.seek(with: options)
  }

  func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
    onStatus(statusPayload())
  }

  func statusPayload() -> [String: Any] {
    guard let session = session else { return disconnectedPayload() }
    var state = "connected"
    if let status = client?.mediaStatus {
      switch status.playerState {
      case .playing: state = "playing"
      case .paused: state = "paused"
      case .buffering, .loading: state = "buffering"
      default: state = "connected"
      }
    }
    let position = client?.approximateStreamPosition() ?? 0
    let duration = client?.mediaStatus?.mediaInformation?.streamDuration ?? 0
    let payload: [String: Any] = [
      "state": state,
      "kind": "chromecast",
      "deviceName": session.device.friendlyName ?? "Chromecast",
      "positionSeconds": wholeSeconds(position),
      "durationSeconds": wholeSeconds(duration),
    ]
    return payload
  }

  private func disconnectedPayload() -> [String: Any] {
    let payload: [String: Any] = [
      "state": "disconnected",
      "kind": "chromecast",
      "deviceName": NSNull(),
      "positionSeconds": 0,
      "durationSeconds": 0,
    ]
    return payload
  }
}

// MARK: - Helpers

private func wholeSeconds(_ value: Double) -> Int {
  value.isFinite && value > 0 ? Int(value) : 0
}

private func keyWindow() -> UIWindow? {
  UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }
}
