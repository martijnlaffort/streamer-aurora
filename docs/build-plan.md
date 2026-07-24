# Build plan — "Aurora" IPTV player (Claude Code tasks)

This is the execution plan for the real app. Run it **one task at a time**: paste the task,
let Claude Code finish, verify the **Definition of done (DoD)**, commit, then move to the next.
Don't run two tasks in one prompt.

## Before you start

1. Put `iptv-player-prd.md` and this file in a `/docs` folder in the repo so Claude Code can
   read them. Every task refers back to the PRD for detail (e.g. "per PRD §8.9").
2. Do day-to-day dev on the **Android emulator** or the **Flutter Windows desktop** target
   (both run `media_kit`). Push to iPhone via the CI → Sideloadly pipeline only at milestones.
3. Only start this after the smoke test passed. If it hasn't, stop and fix that first.

## Global rules (apply to EVERY task — tell Claude Code to treat these as standing constraints)

- **Verify package versions on pub.dev — never pin from memory.** Follow each package's
  official setup.
- **Defensive parsing everywhere.** Any catalog field can be missing, null, or the wrong
  type. Skip and log bad rows; never crash on a malformed catalog.
- **All timestamps stored in UTC.** Display in local time only at the edge.
- **Repositories are local-first with a sync seam** (per PRD §9) — local is the source of
  truth; leave a clean interface for a future backend. Don't build the backend yet.
- **Credentials go in `flutter_secure_storage`**, never in plain SQLite.
- **The UI must stay source-agnostic** — it talks to repositories and domain models only,
  never directly to Xtream/M3U specifics.
- Carry the **iOS ATS exception and deployment target** from the smoke test into this project.
- After each task, run `flutter analyze` and leave it clean.

---

# Phase 0 — Foundations

### Task 0.1 — Project scaffold & architecture skeleton

```
Create a new Flutter app (iOS + Android; we develop on Android/Windows first) following the
architecture in /docs/iptv-player-prd.md §5.

- Set up a feature-first folder structure: core/ (theme, router, utils), data/ (sources,
  repositories, local db), domain/ (models), features/ (home, movies, series, player,
  search, settings).
- Add and configure dependencies (check current stable versions on pub.dev): flutter_riverpod,
  media_kit + media_kit_video + iOS/Android native libs, drift + sqlite3_flutter_libs, dio,
  flutter_secure_storage, cached_network_image, go_router.
- Define immutable domain models with value equality (per PRD §5/§7): Account, Category, Movie,
  Series, Season, Episode, Channel, EpgEntry, StreamRef, WatchProgress, Preferences.
- Add a dark, cinematic theme scaffold (placeholder tokens per PRD §10) and a single blank
  Home screen behind go_router.
- Carry over the iOS ATS Info.plist exception and the media_kit deployment target from the
  smoke test.

DoD: app builds and runs on Android emulator AND Windows desktop showing a blank themed Home;
all models compile; `flutter analyze` is clean. Do NOT build any data fetching or UI yet.
```

### Task 0.2 — Source abstraction + Xtream client

```
Implement the source abstraction from PRD §5 and the Xtream client from PRD §6.1.

- Define a `PlaylistSource` interface covering: authenticate, live categories/streams, VOD
  categories/streams, VOD info, series categories/list/info, short EPG, and stream-URL builders
  for live/movie/series.
- Implement `XtreamSource` with dio against player_api.php. Map raw JSON to the domain models.
  Apply the global defensive-parsing rule. Build stream URLs exactly per PRD §6.1.
- Add a tiny dev harness (a debug screen or a test) that, given credentials I enter at runtime,
  fetches and prints category counts and a few sample items from each type.

DoD: with real credentials it authenticates and lists live/VOD/series categories and sample
streams; malformed entries are skipped, not fatal. Include unit tests for the JSON→model
mapping using saved sample-response fixtures. Do NOT build catalog caching or UI yet.
```

### Task 0.3 — M3U source

```
Implement `M3uSource` per PRD §6.2, producing the SAME domain models as XtreamSource so the
rest of the app can't tell them apart.

- Parse #EXTINF attributes (tvg-id, tvg-name, tvg-logo, group-title) + URL lines. Map
  group-title to categories. Accept an optional separate XMLTV EPG URL.
- Handle malformed/partial lines gracefully.

DoD: parses a sample M3U (live-only and a mixed one) into domain models; unit tests cover
well-formed and malformed input. Do NOT wire it to UI yet.
```

### Task 0.4 — Local persistence, caching & repositories

```
Build the storage layer per PRD §7 and the repository layer per PRD §5, §9.

- drift schema for: accounts, categories, movies, series, episodes, channels, watch_progress,
  preferences, favorites, epg_cache. All timestamps UTC. Store credential references only;
  actual passwords/tokens go in flutter_secure_storage.
- CatalogRepository: fetch via the active source, cache to drift with a TTL, refresh in the
  background, serve from cache when offline. Use lazy/paged reads for large catalogs.
- WatchProgressRepository, PreferencesRepository, FavoritesRepository — local-first with a
  sync seam (interface ready for a future backend; no backend now).

DoD: I can save an account, cache a full catalog, and read it back with the network off;
credentials are verified to live in secure storage; all written timestamps are UTC. Unit tests
for the repositories with a fake source. Do NOT build onboarding UI yet.
```

### Task 0.5 — Account onboarding flow

```
Build account onboarding per PRD §8.1.

- Add-account screen supporting Xtream (server URL, username, password) and M3U (URL or file +
  optional EPG URL). Validate on save (Xtream: an auth ping; M3U: a parse check) with clear
  success/error states.
- Support multiple saved accounts and switching the active one.
- On successful add, kick off catalog caching with a visible progress indicator.

DoD: I can add a real Xtream or M3U account, see validation feedback, and watch the catalog
cache populate. Switching accounts swaps the active catalog.
```

**End of Phase 0:** you have data flowing and cached, source-agnostic, with accounts. No real UI yet — that's Phase 1.

---

# Phase 1 — MVP (VOD-first, mobile)

### Task 1.1 — Navigation shell + Home

```
Build the app shell and Home per PRD §8.2 and §10.

- go_router shell with bottom navigation: Home, Movies, Series, Search, Settings.
  (Live TV comes in Phase 2 — leave a placeholder or omit for now.)
- Home: a featured hero (recently added), a Continue Watching rail (wired to
  WatchProgressRepository; empty for now is fine), and category rails. Horizontally scrolling
  poster cards with lazy-loaded images (cached_network_image). Tapping a card routes to detail.

DoD: Home renders real rails from the cached catalog with real posters; navigation between
tabs works; scrolling is smooth on a large catalog.
```

### Task 1.2 — Movies (VOD) browse + detail

```
Build Movies browsing and the movie detail page per PRD §8.3 and §8.7.

- Movies grid with category filter and sort (added/name/rating), lazy images.
- Detail page: backdrop, poster, plot, cast, genre, year, rating, duration (from get_vod_info),
  a context-aware primary button (Play, or "Resume from HH:MM" when progress exists) with a
  secondary "Start over", and a favorite toggle.

DoD: I can browse cached VOD, filter/sort, and open a detail page populated from get_vod_info.
The play button reflects resume state (even if playback isn't wired until 1.4).
```

### Task 1.3 — Series browse + detail

```
Build Series browsing and detail per PRD §8.4 and §8.7.

- Series grid (same browse UX as movies).
- Detail page with a season selector and episode list; per-episode watched/progress indicators;
  the primary action targets the next unwatched episode.

DoD: I can browse series and open a detail page showing seasons and episodes with progress
indicators.
```

### Task 1.4 — The player (core)

```
Build the media_kit player per PRD §8.8, reusing the setup validated in the smoke test.

- Custom controls overlay (HBO-style): play/pause, seek bar with buffer indicator, skip ±10s,
  title, back.
- Audio track selector and subtitle track selector (with an explicit "Off"), listing tracks
  with language labels.
- Gestures: vertical swipe for brightness (left) / volume (right); horizontal drag to seek;
  double-tap to skip.
- Buffering, error, and retry states. Lock-controls toggle.
- Autoplay-next for series episodes with an "Up next" countdown (respect the setting from 1.7).

DoD: movies and episodes play; I can manually switch audio and subtitle tracks mid-playback;
errors show a retry. Test on Windows desktop and on the iPhone via the pipeline.
```

### Task 1.5 — Resume / Continue Watching

```
Implement resume logic per PRD §8.9.

- Save playback position every ~5s and on pause/background/exit.
- On opening content with saved progress: offer Resume when 5% < position < 95%, else start
  fresh. Mark completed at ~95% (or last ~90s); remove from Continue Watching; for series,
  advance the "next episode".
- Sort the Home Continue Watching rail by updated_at desc.

DoD: closing the app mid-movie and reopening returns me to within a few seconds of where I left
off, across full app restarts; completed items leave the rail; series surface the next episode.
```

### Task 1.6 — Language preference logic

```
Implement audio/subtitle language preferences per PRD §8.10 — this is a headline feature.

- Global preferred audio language and preferred subtitle language (or "Off") in Settings.
- On every stream load, enumerate tracks and auto-select the track whose language tag matches
  the preference; fall back gracefully if absent.
- Learn on manual change: when I switch a track by hand, update the global preference (with an
  optional per-content override).

DoD: after setting audio=English and subtitles=Dutch once, every subsequent stream that has
those tracks selects them automatically with no interaction.
```

### Task 1.7 — Search, Favorites, Settings

```
Build search, favorites, and settings per PRD §8.6, §8.11, §8.12.

- Search: unified over movies, series, and (later) channels, searching the cached catalog first
  so results are instant; debounced input.
- Favorites: toggle from detail pages; a Favorites view aggregating across types.
- Settings: accounts management, preferred audio/subtitle language, autoplay-next toggle, cache
  size + clear + force refresh, theme (dark default).

DoD: search returns cached results instantly as I type; favorites toggle and appear in the
Favorites view; settings persist across restarts.
```

### Task 1.8 — HBO-style visual pass

```
Do a dedicated visual/polish pass to hit the target look per PRD §10. Use your frontend-design
skill for this task.

- Apply the dark cinematic design system: typography, spacing, gradients/blur behind text over
  imagery, snappy poster-rail momentum and focus/scale states, and shared-element-style
  transitions from poster → detail.
- Build the components focus-aware so the Android TV layer (Phase 3) can reuse them.

DoD: the app reads as a finished, HBO-Max-adjacent product, not a prototype — on both a phone
and the Windows desktop build.
```

**End of Phase 1:** a working, good-looking VOD + series player on your iPhone with resume and
remembered languages — the three things Smarters got wrong, fixed.

---

# Phase 2 & 3 — outline (spec these into tasks after the MVP is real)

- **Phase 2 — Live + polish:** Live TV list + EPG guide (PRD §8.5), autoplay-next refinements,
  Picture-in-Picture, then the thin Laravel sync backend on Hetzner/Ploi (PRD §9) and iOS
  distribution hardening.
- **Phase 3 — Android TV:** leanback/D-pad UI layer reusing the focus-aware components,
  TV-optimized player controls, optional Chromecast.

Build these as their own one-task-at-a-time prompts once Phase 1 is stable on your device.

---

## Execution notes (added during Task 0.1)

- `sqlite3_flutter_libs` is published as `0.6.0+eol` (end of life) — the current official
  drift setup is `drift` + `drift_flutter` + `path_provider`. Task 0.4 should use that.
- App identity: project name `aurora`, placeholder id `com.example.aurora` (deliberate —
  rename later if wanted).
- Local toolchain lives on D: (`D:\dev\flutter`, `D:\Android\sdk`); Flutter pinned 3.44.8
  locally and in CI.
- Task 0.2: added `genre`/`cast` to Movie and Series (get_vod_info/get_series provide them;
  detail pages per PRD §8.7 need them) and a `SeriesDetail` aggregate for get_series_info.
  The dev harness lives at `/dev/source-probe` (bug icon on Home, debug builds only).
