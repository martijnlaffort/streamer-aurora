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

Toolchain lives on D:. Flutter is pinned to **3.44.8** (match CI when bumping):

- Flutter SDK: `D:\dev\flutter` (`PUB_CACHE=D:\dev\pub-cache`)
- VS 2022 Build Tools (C++ workload, incl. ATL): `D:\dev\VS\BuildTools`
- JDK: Temurin 17, `D:\dev\jdk\temurin-17` (`JAVA_HOME`)
- Android SDK: `D:\Android\sdk` (`ANDROID_HOME`), AVDs in `D:\Android\avd`

```sh
flutter pub get
flutter run -d windows            # fast dev loop
flutter emulators --launch aurora_api36   # AVD name predates the rename
flutter run -d emulator-5554      # Android
flutter analyze                   # must stay clean (global rule)
```

## iOS

The `ios/` scaffold is committed. `ios/Runner/Info.plist` carries the App Transport
Security exception (IPTV panels are plain HTTP) and `ios/Podfile` pins deployment target
15.0 (above media_kit's 13.0 floor; Apple blocks uploads below 15.0 from Spring 2027);
`tool/patch_ios.sh` re-asserts both, idempotently.

CI (`.github/workflows/ios-unsigned.yml`) builds an **unsigned** `app-unsigned.ipa`
artifact on every push to `main` (or manually via workflow_dispatch). Sideload it with
Sideloadly + a free Apple ID (7-day resign). Push to the iPhone at milestones only;
day-to-day dev happens on Windows/Android.
