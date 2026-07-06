# streamer-aurora

A **throwaway** Flutter smoke-test app. One ugly screen. It exists to validate three
things on a physical iPhone sideloaded with a free Apple ID, then get deleted:

1. `media_kit` (libmpv) compiles for iOS and plays an IPTV stream.
2. Audio + subtitle tracks enumerate on iOS and can be switched at runtime.
3. The app can be built **unsigned** in CI and packaged into an `.ipa` for sideloading.

This is **not** the IPTV app — no Xtream API, no catalog, no database, no navigation,
no theming. `setState` only.

## Versions used

| Component            | Version                                    |
|----------------------|--------------------------------------------|
| Flutter              | `3.24.5` (stable) — pinned in CI           |
| media_kit            | `^1.2.6`                                    |
| media_kit_video      | `^2.0.1`                                    |
| media_kit_libs_video | `^1.0.7` (pulls `media_kit_libs_ios_video`)|
| iOS min deployment   | `13.0`                                      |

The authoritative Flutter version for any given run is whatever `flutter --version`
prints in the CI log (first step of the workflow). Package versions are the current
stable releases on pub.dev at the time of writing; `pubspec.yaml` uses caret ranges.

## The one screen

- A `TextField` pre-filled with `http://example.com/live/user/pass/12345.ts` — paste a
  real stream URL over it.
- **Play** opens the URL in a `media_kit` `Player`.
- A `media_kit_video` `Video` widget shows playback.
- Below the video: detected **audio tracks** and **subtitle tracks** as tappable rows
  (`id` + language + title), plus an explicit **"Subtitles: Off"** row. Tap to switch;
  the selected row is highlighted.
- Player state (`idle / opening / buffering / playing / error`) is shown, color-coded.
  On error the error text is printed **on screen** (red banner) — failures are legible
  on the device, not just in logs.
- On launch the app logs (via `debugPrint`) the media_kit versions and iOS deployment
  target. The exact Flutter version comes from CI `flutter --version`.

## iOS setup performed

These are the parts that silently fail if skipped:

- **App Transport Security.** Most IPTV panels serve plain HTTP, which iOS blocks by
  default. `ios/Runner/Info.plist` sets:
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
  ```
- **Deployment target 13.0** (media_kit/libmpv requires it): `ios/Podfile`
  (`platform :ios, '13.0'` + a `post_install` loop forcing every pod to 13.0) and the
  Xcode project's `IPHONEOS_DEPLOYMENT_TARGET` (set by `tool/patch_ios.sh`).
- **Minimal entitlements.** No push, no associated domains, no background modes — a
  free-account provisioning profile is limited, so nothing that needs special
  entitlements was added.

### Why the iOS scaffold isn't fully committed

Only the files that are genuine *edits* are committed: `ios/Runner/Info.plist` and
`ios/Podfile`. The rest of the iOS scaffold (`project.pbxproj`, storyboards,
`xcworkspace`, xcconfigs) is generated deterministically by `flutter create
--platforms=ios .` — checking in a hand-edited `pbxproj` is fragile and version-specific.
`tool/patch_ios.sh` then re-asserts the ATS block and the 13.0 deployment target so the
config is correct no matter what the generator produced. It's idempotent.

## Build the unsigned IPA (CI)

`.github/workflows/ios-unsigned.yml` runs on `macos-latest`:

1. Install pinned Flutter.
2. `flutter create --platforms=ios .` — generate the iOS scaffold.
3. `tool/patch_ios.sh` — re-assert ATS + deployment target.
4. `flutter build ios --release --no-codesign` — compile the `.app` (pod install runs
   automatically).
5. Package the `.app` into `app-unsigned.ipa` via the `Payload/` zip trick — because
   `flutter build ipa --no-codesign` does **not** emit an `.ipa` (it needs a team id).
6. Upload `app-unsigned.ipa` as a build artifact.

Trigger it via the **Actions** tab (`workflow_dispatch`) or a push to `main`.

> **Make the GitHub repo public** so macOS runner minutes are free — private repos bill
> macOS at 10× the free allowance. There are no secrets here: the stream URL is pasted
> at runtime, never committed.

Then sideload `app-unsigned.ipa` with your tool of choice (AltStore / Sideloadly), which
re-signs it with your free Apple ID.

## Run locally (macOS, on-device)

```sh
flutter pub get
flutter create --platforms=ios .   # generate the iOS scaffold once
bash tool/patch_ios.sh             # ATS + deployment target
flutter run --release              # on a connected iPhone (Xcode will re-sign)
```

For a free Apple ID you'll need to open `ios/Runner.xcworkspace` in Xcode once, set your
Signing Team and a unique bundle identifier, then run.

## Smoke-test checklist

- [ ] App launches on the iPhone without crashing.
- [ ] Pasting a real IPTV URL and tapping Play shows video (state → `playing`).
- [ ] Audio tracks list populates; tapping a different one changes the audio.
- [ ] Subtitle tracks list populates; tapping one shows subtitles; **Subtitles: Off** hides them.
- [ ] A bad URL surfaces a visible red error banner on screen.
