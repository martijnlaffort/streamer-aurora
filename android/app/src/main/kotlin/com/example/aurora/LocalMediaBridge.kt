package com.example.aurora

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/**
 * The device's own files, over `dawnplayer/local_media` (methods) and
 * `dawnplayer/local_media/opened` (files opened in the app from a file manager,
 * a share sheet or "Open with"). The iOS side is LocalMediaBridge in
 * AppDelegate.swift; both speak the same payloads.
 *
 * Videos are played where they are, through a descriptor opened from their
 * `content://` URI (see [resolve]) — never copied, since a film can be
 * gigabytes. Files picked inside the app come from ACTION_OPEN_DOCUMENT, whose
 * read permission is persisted, so they still open after a restart and resume
 * works. A file another app shared for one session only cannot be reopened
 * later; [isAvailable] lets Continue Watching say so instead of failing. Subtitles and playlists are small and are copied into the
 * app's own storage instead.
 */
class LocalMediaBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private var sink: EventChannel.EventSink? = null

    /** Files opened before Dart started listening: the one that launched us. */
    private val pending = mutableListOf<Map<String, Any?>>()

    private var pickResult: MethodChannel.Result? = null
    private var pickKind = "video"

    init {
        MethodChannel(messenger, "dawnplayer/local_media").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> pick(call.argument<String>("kind") ?: "video", result)
                "resolve" -> result.success(resolve(call.argument<String>("ref") ?: ""))
                "isAvailable" -> result.success(isAvailable(call.argument<String>("ref") ?: ""))
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "dawnplayer/local_media/opened").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    pending.forEach { events?.success(it) }
                    pending.clear()
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
    }

    private fun pick(kind: String, result: MethodChannel.Result) {
        if (pickResult != null) {
            result.error("busy", "A picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Subtitles and playlists have no MIME type providers agree on, so
            // the picker shows everything for those.
            type = "*/*"
            if (kind == "video") {
                putExtra(Intent.EXTRA_MIME_TYPES, VIDEO_MIMES)
            }
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        pickResult = result
        pickKind = kind
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: ActivityNotFoundException) {
            // Some TV builds ship without a document picker at all.
            pickResult = null
            result.error("no_picker", "This device has no file picker", null)
        }
    }

    /** Returns true when the result was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pickResult ?: return true
        pickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        result.success(if (pickKind == "video") videoPayload(uri) else copyPayload(uri))
        return true
    }

    /** A VIEW or SEND intent: a file opened in Dawn Player from elsewhere. */
    fun handleIntent(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra(EXTRA_HANDLED, false)) return
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return
        // Recreating the activity (rotation, a theme change) hands us the same
        // intent again; without this the video would start over each time.
        intent.putExtra(EXTRA_HANDLED, true)
        val name = (displayName(uri) ?: uri.lastPathSegment ?: "").lowercase()
        val mime = intent.type ?: activity.contentResolver.getType(uri)
        val isPlaylist =
            name.endsWith(".m3u") || name.endsWith(".m3u8") || mime in PLAYLIST_MIMES
        val payload = (if (isPlaylist) copyPayload(uri) else videoPayload(uri))
            ?.toMutableMap() ?: return
        payload["kind"] = if (isPlaylist) "playlist" else "video"
        val current = sink
        if (current != null) current.success(payload) else pending.add(payload)
    }

    private fun displayName(uri: Uri): String? = query(uri, OpenableColumns.DISPLAY_NAME) {
        it.getString(0)
    }

    private fun size(uri: Uri): Long? = query(uri, OpenableColumns.SIZE) {
        if (it.isNull(0)) null else it.getLong(0)
    }

    private fun <T> query(uri: Uri, column: String, read: (android.database.Cursor) -> T?): T? =
        try {
            activity.contentResolver.query(uri, arrayOf(column), null, null, null)?.use {
                if (it.moveToFirst()) read(it) else null
            }
        } catch (e: Exception) {
            null
        }

    /** A video, referenced where it is. */
    private fun videoPayload(uri: Uri): Map<String, Any?> {
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // The sender granted access for this session only (common for share
            // sheets). It plays now; after a restart it has to be opened again,
            // and its resume point is still there when it is.
        }
        return mapOf(
            "ref" to uri.toString(),
            "name" to (displayName(uri) ?: uri.lastPathSegment ?: "Video"),
            "size" to size(uri),
            "path" to uri.toString(),
        )
    }

    /** A small file, copied into app storage so it outlives the grant. */
    private fun copyPayload(uri: Uri): Map<String, Any?>? {
        val name = displayName(uri) ?: uri.lastPathSegment ?: "file"
        val safeName = name.replace(Regex("[^\\w.\\- ]"), "_")
        val dir = File(activity.filesDir, "imports").apply { mkdirs() }
        val dest = File(dir, "${UUID.randomUUID()}-$safeName")
        return try {
            val input = activity.contentResolver.openInputStream(uri) ?: return null
            input.use { source -> dest.outputStream().use { source.copyTo(it) } }
            mapOf(
                "ref" to "path:${dest.absolutePath}",
                "name" to name,
                "size" to dest.length(),
                "path" to dest.absolutePath,
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * A stored ref back to something playable, or null when it is gone.
     *
     * A `content://` file is opened here and handed to mpv as `fdclose://<fd>`:
     * mpv reads the descriptor and closes it when playback ends. That works
     * whether or not the bundled FFmpeg was built with Android content-URI
     * support. Called once per open, right before playback, so every
     * descriptor handed out is consumed.
     */
    private fun resolve(ref: String): String? {
        if (ref.startsWith("path:")) {
            val path = ref.removePrefix("path:")
            return if (File(path).canRead()) path else null
        }
        return try {
            val descriptor = activity.contentResolver.openFileDescriptor(Uri.parse(ref), "r")
                ?: return null
            "fdclose://${descriptor.detachFd()}"
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Whether a stored ref can still be opened. False for a file shared with
     * this app for one session only, once that session is over.
     */
    private fun isAvailable(ref: String): Boolean {
        if (ref.startsWith("path:")) return File(ref.removePrefix("path:")).canRead()
        return try {
            activity.contentResolver.openFileDescriptor(Uri.parse(ref), "r")?.use { true } ?: false
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val REQUEST_PICK = 0xDA7
        private const val EXTRA_HANDLED = "com.dawnplayer.player.HANDLED"
        private val VIDEO_MIMES = arrayOf(
            "video/*",
            "application/x-matroska",
            "application/mp4",
        )
        private val PLAYLIST_MIMES = setOf(
            "audio/x-mpegurl",
            "audio/mpegurl",
            "application/x-mpegurl",
            "application/vnd.apple.mpegurl",
        )
    }
}
