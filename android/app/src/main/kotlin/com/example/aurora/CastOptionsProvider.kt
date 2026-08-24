package com.example.aurora

import android.content.Context
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

/**
 * Cast framework configuration, found by name from the manifest meta-data.
 *
 * We target Google's **Default Media Receiver**, which is the stock player every
 * Chromecast already has. That choice is what decides which streams can be cast:
 * it handles MP4, HLS and DASH, but not raw MPEG-TS or MKV. Live channels are
 * therefore cast as HLS (`.m3u8`) where the panel offers it — see castUrlFor on
 * the Dart side, which is the single place that decision lives.
 *
 * A custom receiver (an HTML page of our own, demuxing TS in JavaScript) would
 * widen that set, but it needs a registered application id and would run the
 * demux on some fairly weak hardware. Not worth it until the stock path proves
 * itself.
 */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions {
        return CastOptions.Builder()
            .setReceiverApplicationId(
                CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID,
            )
            // We drive everything from Flutter, so none of the framework's own
            // notification/lock-screen UI is wanted.
            .setStopReceiverApplicationWhenEndingSession(true)
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context): MutableList<SessionProvider>? =
        null
}
