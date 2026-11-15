# Dawn Player

A modern, HBO-Max-style IPTV player for Xtream Codes and M3U sources, built with Flutter
and `media_kit` (libmpv). Simpler than Smarters Player Lite, with the three things it gets
wrong done right: reliable playback, resume/continue-watching, and remembered
audio/subtitle languages.

- **PRD:** [docs/iptv-player-prd.md](docs/iptv-player-prd.md)
- **Build plan (task-by-task):** [docs/build-plan.md](docs/build-plan.md)
- The original media_kit iOS smoke test lives at git tag `smoke-test-ios`.

## Architecture (PRD §5)

Feature-first layout; the UI talks to repositories and domain models only — never to
Xtream/M3U specifics:

```
lib/
  core/       theme, router, utils
  data/       sources (Xtream/M3U), repositories, local db (drift)
  domain/     immutable models (equatable)
  features/   home, movies, series, player, search, settings
```

Standing rules: defensive parsing everywhere; all stored timestamps UTC; credentials in
flutter_secure_storage only; repositories are local-first with a sync seam (PRD §9).

## Development (Windows)

Flutter is pinned to **3.44.8**; CI uses the same version, so bump both together.

- Flutter SDK: `C:\src\flutter`, cloned at tag `3.44.8`, with `C:\src\flutter\bin` on `PATH`.
- Android Studio: provides the Android SDK (`%LOCALAPPDATA%\Android\Sdk`), the emulator and the
  JDK that Gradle uses (bundled, no separate install).
- Optional, only for `flutter run -d windows`: Visual Studio 2022 Build Tools with the
  "Desktop development with C++" workload.

First-time setup:

```powershell
git clone -b 3.44.8 https://github.com/flutter/flutter.git C:\src\flutter
# Add C:\src\flutter\bin to the user PATH, then open a new terminal.
flutter --version                  # must say 3.44.8
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"   # after Android Studio's setup wizard
flutter doctor --android-licenses
flutter doctor
```

Daily use:

```sh
flutter pub get
flutter analyze --fatal-infos     # must stay clean (CI runs exactly this)
flutter test
flutter build apk --debug
flutter run -d emulator-5554      # Android emulator, or a phone with USB debugging
```

iOS builds need macOS. Without a Mac, `ios-unsigned.yml` (Actions → iOS Unsigned Build → Run
workflow) builds the app on a GitHub macOS runner.

## iOS

The `ios/` scaffold is committed. `ios/Runner/Info.plist` carries the App Transport
Security exception (IPTV panels are plain HTTP) and `ios/Podfile` pins deployment target
15.0 (above media_kit's 13.0 floor; Apple blocks uploads below 15.0 from Spring 2027);
`tool/patch_ios.sh` re-asserts both, idempotently.

CI (`.github/workflows/ios-unsigned.yml`) builds an **unsigned** `app-unsigned.ipa`
artifact on every push to `main` (or manually via workflow_dispatch). Sideload it with
Sideloadly + a free Apple ID (7-day resign). Push to the iPhone at milestones only;
day-to-day dev happens on Windows/Android.
