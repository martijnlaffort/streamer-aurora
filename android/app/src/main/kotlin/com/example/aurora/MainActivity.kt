package com.example.aurora

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var cast: CastBridge? = null

    /**
     * Reports whether we are running on a television, so the Flutter layer can
     * switch to the D-pad / 10-foot UI (PRD Phase 3).
     *
     * This has to come from the platform: screen size is not a usable proxy — a
     * tablet or the Windows desktop build is just as large — and Flutter exposes
     * no equivalent. UI_MODE_TYPE_TELEVISION is exactly what Android reports on
     * a leanback device such as the Google TV Streamer.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dawnplayer/platform",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                else -> result.notImplemented()
            }
        }
        cast = CastBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        cast?.dispose()
        cast = null
        super.onDestroy()
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }
        // Some leanback devices report a normal ui mode; the system feature is a
        // second opinion rather than a replacement.
        return packageManager.hasSystemFeature("android.software.leanback")
    }
}
