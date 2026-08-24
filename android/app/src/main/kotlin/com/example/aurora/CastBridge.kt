package com.example.aurora

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Chromecast, exposed to Flutter as a small command/event surface.
 *
 * Deliberately does NOT use any of the Cast framework's own widgets. The
 * MediaRouteButton and its device dialog are phone-shaped Material views that
 * cannot be driven with a D-pad and would look foreign inside this app, so the
 * picker is built in Flutter from the device list published here.
 *
 * Everything the framework needs happens on the main thread; the discovery
 * callback and the media-status callback both arrive there too, so the event
 * sinks are only ever touched from one thread.
 */
class CastBridge(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())

    private var castContext: CastContext? = null
    private var mediaRouter: MediaRouter? = null
    private var selector: MediaRouteSelector? = null

    private var devicesSink: EventChannel.EventSink? = null
    private var statusSink: EventChannel.EventSink? = null

    /** Routes seen so far, keyed by the id Flutter sends back to connect. */
    private val routes = mutableMapOf<String, MediaRouter.RouteInfo>()

    private val methodChannel =
        MethodChannel(messenger, "dawnplayer/cast").apply {
            setMethodCallHandler(::onMethodCall)
        }

    init {
        EventChannel(messenger, "dawnplayer/cast/devices").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    devicesSink = sink
                    publishDevices()
                }

                override fun onCancel(arguments: Any?) {
                    devicesSink = null
                }
            },
        )
        EventChannel(messenger, "dawnplayer/cast/status").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    statusSink = sink
                    publishStatus()
                }

                override fun onCancel(arguments: Any?) {
                    statusSink = null
                }
            },
        )
    }

    // --- Lifecycle -----------------------------------------------------------

    /**
     * Cast is unavailable on plenty of real devices — no Play Services, an
     * emulator, a stripped Android TV image — and getSharedInstance throws there
     * rather than returning null. Failing softly matters: the Flutter side hides
     * the cast button instead of the app dying on a screen the user opened by
     * accident.
     */
    private fun ensureContext(): CastContext? {
        castContext?.let { return it }
        return try {
            val ctx = CastContext.getSharedInstance(context)
            ctx.sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
            castContext = ctx
            ctx
        } catch (e: Throwable) {
            null
        }
    }

    fun dispose() {
        stopDiscovery()
        castContext?.sessionManager
            ?.removeSessionManagerListener(sessionListener, CastSession::class.java)
        remoteClient()?.unregisterCallback(mediaCallback)
        methodChannel.setMethodCallHandler(null)
    }

    // --- Method channel ------------------------------------------------------

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(ensureContext() != null)
            "startDiscovery" -> {
                startDiscovery()
                result.success(null)
            }
            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }
            "connect" -> {
                val id = call.argument<String>("id")
                val route = id?.let { routes[it] }
                if (route == null) {
                    result.error("no_device", "That device is no longer visible.", null)
                } else {
                    mediaRouter?.selectRoute(route)
                    result.success(null)
                }
            }
            "disconnect" -> {
                // `true` stops the receiver app, so the TV drops back to its own
                // home screen rather than sitting on a paused Dawn Player.
                castContext?.sessionManager?.endCurrentSession(true)
                result.success(null)
            }
            "load" -> {
                val client = remoteClient()
                if (client == null) {
                    result.error("no_session", "Not connected to a device.", null)
                    return
                }
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("bad_args", "A url is required.", null)
                    return
                }
                val metadata = MediaMetadata(
                    if (call.argument<Boolean>("isLive") == true) {
                        MediaMetadata.MEDIA_TYPE_GENERIC
                    } else {
                        MediaMetadata.MEDIA_TYPE_MOVIE
                    },
                )
                call.argument<String>("title")?.let {
                    metadata.putString(MediaMetadata.KEY_TITLE, it)
                }
                call.argument<String>("subtitle")?.let {
                    metadata.putString(MediaMetadata.KEY_SUBTITLE, it)
                }
                val info = MediaInfo.Builder(url)
                    .setStreamType(
                        if (call.argument<Boolean>("isLive") == true) {
                            MediaInfo.STREAM_TYPE_LIVE
                        } else {
                            MediaInfo.STREAM_TYPE_BUFFERED
                        },
                    )
                    .setContentType(call.argument<String>("contentType") ?: "video/mp4")
                    .setMetadata(metadata)
                    .build()
                val startSeconds = (call.argument<Number>("positionSeconds") ?: 0).toLong()
                client.registerCallback(mediaCallback)
                client.load(
                    MediaLoadRequestData.Builder()
                        .setMediaInfo(info)
                        .setAutoplay(true)
                        .setCurrentTime(startSeconds * 1000)
                        .build(),
                )
                result.success(null)
            }
            "play" -> { remoteClient()?.play(); result.success(null) }
            "pause" -> { remoteClient()?.pause(); result.success(null) }
            "stop" -> { remoteClient()?.stop(); result.success(null) }
            "seek" -> {
                val seconds = (call.argument<Number>("positionSeconds") ?: 0).toLong()
                remoteClient()?.seek(
                    com.google.android.gms.cast.MediaSeekOptions.Builder()
                        .setPosition(seconds * 1000)
                        .build(),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- Discovery -----------------------------------------------------------

    private fun startDiscovery() {
        val ctx = ensureContext() ?: return
        if (mediaRouter != null) return
        val router = MediaRouter.getInstance(context)
        val appId = ctx.castOptions.receiverApplicationId
        val sel = MediaRouteSelector.Builder()
            .addControlCategory(CastMediaControlIntent.categoryForCast(appId))
            .build()
        mediaRouter = router
        selector = sel
        // ACTIVE_SCAN finds devices quickly, which is what a picker needs; it is
        // stopped again as soon as the picker closes because it is power-hungry.
        router.addCallback(
            sel,
            routerCallback,
            MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN,
        )
        publishDevices()
    }

    private fun stopDiscovery() {
        mediaRouter?.removeCallback(routerCallback)
        mediaRouter = null
        selector = null
    }

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()

        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()

        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()
    }

    private fun publishDevices() {
        val sink = devicesSink ?: return
        val router = mediaRouter
        val sel = selector
        routes.clear()
        val list = mutableListOf<Map<String, Any?>>()
        if (router != null && sel != null) {
            for (route in router.routes) {
                if (route.isDefault || !route.matchesSelector(sel)) continue
                routes[route.id] = route
                list.add(
                    mapOf(
                        "id" to route.id,
                        "name" to route.name,
                        "description" to route.description,
                        "connected" to (route.isSelected && isConnected()),
                    ),
                )
            }
        }
        main.post { sink.success(list) }
    }

    // --- Session + media status ---------------------------------------------

    private fun session(): CastSession? = castContext?.sessionManager?.currentCastSession

    private fun remoteClient(): RemoteMediaClient? = session()?.remoteMediaClient

    private fun isConnected(): Boolean = session()?.isConnected == true

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(s: CastSession, sessionId: String) {
            s.remoteMediaClient?.registerCallback(mediaCallback)
            publishDevices()
            publishStatus()
        }

        override fun onSessionResumed(s: CastSession, wasSuspended: Boolean) {
            s.remoteMediaClient?.registerCallback(mediaCallback)
            publishStatus()
        }

        override fun onSessionEnded(s: CastSession, error: Int) {
            s.remoteMediaClient?.unregisterCallback(mediaCallback)
            publishDevices()
            publishStatus()
        }

        override fun onSessionStarting(s: CastSession) = publishStatus()
        override fun onSessionEnding(s: CastSession) = Unit
        override fun onSessionResuming(s: CastSession, sessionId: String) = Unit
        override fun onSessionStartFailed(s: CastSession, error: Int) {
            publishDevices()
            publishStatus()
        }
        override fun onSessionResumeFailed(s: CastSession, error: Int) = publishStatus()
        override fun onSessionSuspended(s: CastSession, reason: Int) = publishStatus()
    }

    private val mediaCallback = object : RemoteMediaClient.Callback() {
        override fun onStatusUpdated() = publishStatus()
        override fun onMetadataUpdated() = publishStatus()
    }

    private fun publishStatus() {
        val sink = statusSink ?: return
        val client = remoteClient()
        val s = session()
        val state = when {
            !isConnected() -> "disconnected"
            client == null -> "connected"
            client.isBuffering -> "buffering"
            client.isPlaying -> "playing"
            client.isPaused -> "paused"
            else -> "connected"
        }
        val payload = mapOf(
            "state" to state,
            "deviceName" to s?.castDevice?.friendlyName,
            "positionSeconds" to ((client?.approximateStreamPosition ?: 0L) / 1000),
            "durationSeconds" to ((client?.streamDuration ?: 0L) / 1000),
        )
        main.post { sink.success(payload) }
    }
}
