# Device checks before submitting 1.0.1

Run on a physical iPhone (and an Android phone for the Android items) with the build you will submit. Each item names what to look at if it fails.

## iOS: files arriving from outside

The app runs on the scene lifecycle, so these files never reach the AppDelegate. They come through `LocalMediaBridge`, registered with `registrar.addSceneDelegate` in `didInitializeImplicitFlutterEngine` (needs Flutter 3.38 or later; CI builds with 3.44.8).

1. **App closed.** Force-quit Dawn Player. In Files, long-press a video → Share → Dawn Player. The app should start and play that file. On a cold start the file arrives with the scene connection (`scene(_:willConnectTo:options:)`), not `openURLContexts`.
2. **App in the background.** With Dawn Player open on Home, switch to Files and do the same. It should come forward and play the new file. Repeat while another video is already playing: it should switch to the new one.
3. **Playlist file.** Share an `.m3u` from Files: the add-playlist form opens with the file filled in.

If 1 fails but 2 works, the bridge was probably registered after the scene connected and missed the launch URL; check the registration runs and that `pending` is flushed when Dart starts listening.

## iOS: file providers

4. **iCloud Drive, not downloaded.** In Files, pick an iCloud video showing the cloud icon (remove its download first). Open it in Dawn Player: it should wait, then play; no "file can't be played" error.
5. **Resume after restart.** Play a file opened from Files to ~2:00, force-quit, relaunch, tap it in Continue Watching: it resumes at ~2:00.

## iOS: App Transport Security (narrowed in this build)

6. An `http://` server on your home network plays.
7. An `http://` HLS stream on a public host plays.
8. AirPlay of an `http://` stream to an Apple TV plays.

If any fail, restore `NSAllowsArbitraryLoads` in `ios/Runner/Info.plist` and `tool/patch_ios.sh`, and use `store/apple/ats_fallback_paragraph.txt` in the review notes.

## Android

9. **Picked in the app.** "Open a video file" → pick from Files and from Google Drive. Both play. Force-stop the app and reopen from Continue Watching: both resume. (Playback goes through `fdclose://<fd>`, so it does not depend on FFmpeg's content-URI support.)
10. **Shared for one session.** Share a video from another app (e.g. a gallery or messaging app) to Dawn Player, watch a minute, force-stop, reopen. Its Continue Watching card should read "Open the file again to continue", and tapping it should say the same, not fail in the player.
11. **Seeking a Drive file.** Seek within a Google Drive video. If seeking fails, the provider is handing out a pipe rather than a file; note it, but it is not a blocker.

## Demo

12. Add `https://dawnplayer.com/demo/demo.m3u` on a fresh install: Movies shows Big Buck Bunny and Sintel, no Live tab, both play, and Sintel's subtitle menu lists every language with French remembered on reopen.
