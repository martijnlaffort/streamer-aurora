# App Review screen recording (60–90 s)

Record on a **physical iPhone** with the built-in Screen Recording (Control Centre), microphone off. Portrait unless noted. Start with Dawn Player **deleted and reinstalled from TestFlight**, so the first screen is the real first-run screen.

**Before recording**
- Save `Big_Buck_Bunny.mp4` (any copy of a free video works) to **Files → On My iPhone → Downloads**.
- Have `https://dawnplayer.com/demo/demo.m3u` on the clipboard.
- Wi-Fi on, notifications silenced (Focus → Do Not Disturb).
- In Settings → Audio & subtitles, leave both languages unset, so the language memory is visible on camera.

| Time | Shot | What must be visible |
|---|---|---|
| 0:00–0:05 | Tap the Dawn Player icon on the Home Screen. | App launch, then the first screen with **Open a video file**, **Add a playlist link or file** and **Connect a media server**, in that order, and "Dawn Player includes no content." |
| 0:05–0:20 | Press Home, open **Files**, go to Downloads, long-press the video → **Share** → **Dawn Player**. | The share sheet showing Dawn Player; the video starts playing in Dawn Player. |
| 0:20–0:28 | Let it play ~5 s, scrub to about 2:00 with the seek bar, let it play 2–3 s more. | A position clearly past the start. |
| 0:28–0:38 | Swipe up to the App Switcher and swipe Dawn Player away (fully quit). Tap the icon again. | Home now shows **Continue Watching** with the file and a progress bar. |
| 0:38–0:45 | Tap the card. | Playback resumes at about 2:00 (pause briefly so the timestamp is readable). |
| 0:45–0:58 | Back to Home. Tap **Add a playlist link or file**, paste the link into **Playlist link**, tap **Connect**, then **Start watching**, then the **Movies** tab. | "Films: 3 found", no login anywhere, then the three demo titles. |
| 0:58–1:12 | Open the **Apple HLS sample** and play it (landscape is fine). Tap **Audio & subtitles** and pick **French** (or any non-default) subtitles. | The panel listing several subtitle languages; French subtitles appearing on the video. |
| 1:12–1:25 | Close the player, then open the HLS sample again from its poster. | French subtitles are on from the first second, with no tap. Optionally open **Audio & subtitles** to show French already ticked. |
| 1:25–1:30 | Close the player; end on Home. | Continue Watching with both the file and the demo titles. |

**Do not show**: Settings → Account details, the media server form filled in, any third-party playlist, or any other app's content.

**Upload**: attach the recording to your reply in App Store Connect (Resolution Center), and mention it in the reply text (already in `reply_to_app_review.txt`).
