# PRD — Dawn Player, an IPTV player

A modern, HBO Max–style IPTV player for Xtream Codes and M3U sources. Simpler than
Smarters Player Lite, but with a premium UI and the three things Smarters gets wrong:
reliable playback, resume/continue-watching, and remembered audio/subtitle languages.

---

## 1. Goals & non-goals

**Primary goals**

1. A clean, modern, HBO Max–style browsing and playback experience.
2. Reliable playback of the messy stream formats IPTV throws at you (raw MPEG-TS, HLS, HEVC/H.265, MKV).
3. Resume playback — remember exactly where every movie/episode was left off ("Continue Watching").
4. Remember preferred audio + subtitle language and auto-apply them on every stream.
5. Only the features actually used — no recording, catch-up, or settings sprawl.

**Non-goals (explicitly out of scope)**

- DVR / recording / catch-up TV.
- Multi-user profiles, parental PIN (may revisit later, not MVP).
- Offline downloads of VOD.
- Being an App Store product — this is a personal/sideloaded app (see §3).

---

## 2. Target platforms

- **Phase 1–2:** iOS + Android (phone/tablet).
- **Phase 3:** Android TV (leanback / D-pad navigation) as an additive UI layer on the same codebase.

---

## 3. Distribution reality (read this before planning releases)

IPTV players that bundle provider access are routinely rejected from the App Store and
Play Store, so plan for **self-distribution**, not store review:

- **Android:** build an APK/AAB and sideload. Trivial. This is the low-friction path and a
  good reason to build/test on Android first.
- **iOS:** personal Apple dev cert (7-day resign) via Sideloadly/AltStore, or an Apple
  Developer account for TestFlight/ad-hoc (1-year). Budget for this friction.
- **Android TV:** sideload APK; no store dependency.

---

## 4. Tech stack (locked)

| Layer | Choice | Why |
|---|---|---|
| Framework | **Flutter** | Single codebase for iOS + Android + Android TV; best-in-class rendering for a media-browsing UI (smooth rails, hero, blur, 60/120fps). |
| Player | **`media_kit`** (libmpv) | Plays essentially any container/codec (MPEG-TS, HLS, HEVC, MKV) **and** exposes audio/subtitle tracks with language tags — directly enables goals 2 & 4. |
| State | **Riverpod** | Testable, composable, good fit for the repository pattern below. (Bloc is fine if preferred.) |
| Local DB | **drift** (or isar) | Type-safe SQLite; stores catalog cache, watch progress, prefs, favorites, EPG cache. |
| Secure storage | **flutter_secure_storage** | Xtream passwords / tokens go in the keychain/keystore, never plain SQLite. |
| HTTP | **dio** | Interceptors, retries, timeouts for flaky panels. |
| Images | **cached_network_image** | Poster/backdrop caching for large catalogs. |
| Sync backend (Phase 2) | **Laravel API** on existing Hetzner/Ploi | Where PHP skills belong in this project — the sync layer, not the client. |

> **Note on NativePHP:** it went free (Air, Feb 2026) and now has a `mobile-media-player`
> plugin, but it wraps AVPlayer/native Android players — which choke on raw MPEG-TS and
> don't yet expose subtitle/audio track selection. That kills goals 2 and 4, so it's the
> wrong tool for the media engine here.

---

## 5. Architecture

**Source abstraction is the backbone.** Both Xtream and M3U normalize into the *same*
domain models, so the entire UI is source-agnostic.

```
PlaylistSource (interface)
 ├── XtreamSource   → player_api.php endpoints
 └── M3uSource      → parsed #EXTINF playlist (+ optional XMLTV EPG url)
        │
        ▼
 Domain models: Movie, Series, Season, Episode, Channel, Category, EpgEntry, StreamRef
        │
        ▼
 Repositories: CatalogRepository, WatchProgressRepository, PreferencesRepository,
               FavoritesRepository, EpgRepository
        │
        ▼
 UI (Riverpod providers) + media_kit player
```

Repositories are the only thing the UI talks to. `WatchProgressRepository` and
`PreferencesRepository` are written **local-first with a sync seam** (see §9) so the
Laravel backend can be added later with zero UI changes.

---

## 6. Data sources

### 6.1 Xtream Codes (primary)

Base: `GET {server}/player_api.php?username={u}&password={p}`

| Purpose | Call |
|---|---|
| Auth / account info | `player_api.php` (no action) → `user_info`, `server_info` |
| Live categories | `&action=get_live_categories` |
| Live streams | `&action=get_live_streams[&category_id=]` |
| VOD categories | `&action=get_vod_categories` |
| VOD list | `&action=get_vod_streams[&category_id=]` |
| VOD detail | `&action=get_vod_info&vod_id={id}` (plot, cast, genre, rating, duration, `container_extension`, backdrop) |
| Series categories | `&action=get_series_categories` |
| Series list | `&action=get_series[&category_id=]` |
| Series detail | `&action=get_series_info&series_id={id}` (seasons → episodes, each with `id` + `container_extension`) |
| EPG now/next | `&action=get_short_epg&stream_id={id}` |
| EPG full day | `&action=get_simple_data_table&stream_id={id}` |
| EPG bulk (XMLTV) | `{server}/xmltv.php?username={u}&password={p}` |

**Stream URL construction**

- Live: `{server}/live/{u}/{p}/{stream_id}.{ext}` (ext often `.ts`, sometimes `.m3u8`)
- VOD: `{server}/movie/{u}/{p}/{stream_id}.{container_extension}`
- Series: `{server}/series/{u}/{p}/{episode_id}.{container_extension}`

> Panels vary wildly. Parse defensively — assume any metadata field can be missing,
> null, or the wrong type. Never crash on a malformed catalog entry; skip and log.

### 6.2 M3U (alternative)

- Parse `#EXTINF:-1 tvg-id="…" tvg-name="…" tvg-logo="…" group-title="…",Display Name` + URL line.
- `group-title` → categories. Usually live-first; VOD/series come via naming conventions if at all.
- EPG via a separately-configured XMLTV URL.
- M3U gives thinner metadata than Xtream — the UI degrades gracefully (fewer posters/plots).

---

## 7. Local data model (SQLite via drift)

- `accounts` — id, type (xtream|m3u), name, server_url, username; **password/token → secure storage**, referenced by key.
- `categories` — id, account_id, type (live|vod|series), name, sort.
- `movies` / `series` / `episodes` / `channels` — cached catalog rows keyed by account_id + stream/series/episode id, with cached_at for TTL.
- `watch_progress` — content_key (account+type+id), position_seconds, duration_seconds, updated_at **(UTC)**, synced_at (nullable), completed (bool).
- `preferences` — preferred_audio_lang, preferred_subtitle_lang (or "off"), autoplay_next (bool), plus per-content overrides table.
- `favorites` — content_key, added_at.
- `epg_cache` — channel_id, start, stop, title, description (TTL-refreshed).

Catalogs can be thousands of rows — cache with a TTL, refresh in the background, and use
virtualized/lazy lists in the UI.

---

## 8. Feature requirements

### 8.1 Onboarding / account setup

- Add account via **Xtream** (server URL, username, password) or **M3U** (URL or file + optional EPG URL).
- Validate on save (Xtream: a `player_api.php` auth ping; M3U: parse check).
- Support multiple saved accounts; switch between them.
- *Acceptance:* invalid credentials show a clear error; valid ones fetch and cache the catalog with a progress indicator.

### 8.2 Home

- Rotating **featured hero** (recently-added or a curated pick).
- **Continue Watching** rail (see §8.9), most-recent first.
- Category rails: Recently Added, plus per-genre/category rails.
- Horizontally scrolling poster cards; tap → detail page.

### 8.3 Movies (VOD)

- Grid, filter by category, sort (added/name/rating).
- Poster + title + rating badge; lazy-loaded images.

### 8.4 Series

- Same browsing as movies.
- Detail page has a **season selector** and episode list.
- Track progress **per episode**; surface the next unwatched episode as the primary action.

### 8.5 Live TV + EPG

- Channel list with category filter and favorites.
- **Now/Next** on each channel; a full **guide view** (time grid) for the day.
- Tap channel → immediate playback with now-playing EPG overlay.
- EPG timezone handled in UTC + display offset (never store local time).

### 8.6 Search

- Unified search across movies, series, and channels.
- Debounced, searches cached catalog first (instant), no network round-trip per keystroke.

### 8.7 Detail pages

- Backdrop + poster, plot, cast, genre, year, rating, duration.
- Primary button is context-aware: **Play**, or **Resume from HH:MM** when progress exists, with a secondary **Start over**.
- Series: season selector + episode list with per-episode watched/progress indicators.
- Add/remove favorite.

### 8.8 Player (media_kit) — the core

- Custom controls overlay (HBO-style): play/pause, seek bar with buffer indicator, skip ±10s, title, back.
- **Audio track selector** — lists tracks with language labels; current selection highlighted.
- **Subtitle track selector** — lists tracks + "Off"; supports embedded and external `.srt`.
- Gesture controls: vertical swipe for brightness (left) / volume (right); horizontal drag to seek; double-tap to skip.
- Buffering + error states with a retry action (panels drop connections).
- Lock-controls toggle; Picture-in-Picture (Phase 2/3).
- **Autoplay next episode** for series (respecting the setting), with a "Up next" countdown.

### 8.9 Continue Watching / resume logic

- Save position every ~5s and on pause/background/exit.
- On opening content with saved progress: if `5% < position < 95%` → offer Resume; else treat as fresh.
- Mark **completed** when position passes ~95% (or last ~90s); remove from Continue Watching and, for series, advance "next episode."
- Home rail sorted by `updated_at` desc.
- *Acceptance:* closing the app mid-movie and reopening returns to within a few seconds of where you left off, across app restarts.

### 8.10 Language preference logic (the other Smarters fix)

- Global **preferred audio language** + **preferred subtitle language** (or "Off") in Settings.
- On every stream load: enumerate tracks, auto-select the track whose language tag matches the preference; fall back gracefully if absent.
- **Learn on manual change:** when the user switches audio/subtitle track manually, update the global preference (with an optional per-content override).
- *Acceptance:* set audio=English, subs=Dutch once; every subsequent stream that has those tracks selects them automatically without interaction.

### 8.11 Favorites / watchlist

- Toggle from detail page and channel list; a Favorites view aggregates across types.

### 8.12 Settings

- Accounts management (add/remove/switch).
- Preferred audio/subtitle language; autoplay-next toggle.
- Cache: size + clear catalog cache; force refresh.
- Theme (dark default; the HBO-style dark palette is the primary experience).
- Sync toggle + backend URL (Phase 2, hidden until built).

---

## 9. Sync strategy — local-first, sync-ready

**Phase 1:** everything local (SQLite). Fully functional, no backend.

**Phase 2:** thin Laravel API on Hetzner/Ploi. Design the seam now so this is drop-in:

- `WatchProgressRepository` / `PreferencesRepository` treat **local as source of truth**;
  a background reconciler pushes/pulls when a backend is configured.
- Reconciliation is **last-write-wins by `updated_at` (UTC)**.
- Suggested endpoints (Sanctum bearer token):
  - `POST /api/progress` (upsert batch), `GET /api/progress?since=`
  - `GET/PUT /api/preferences`
  - `GET/POST/DELETE /api/favorites`
- Device registers once; sync runs on app open and on a light interval.

> Store all timestamps UTC end-to-end. This is the exact class of bug that bit the
> `analytics_events` DST gap — don't reintroduce it in the sync layer.

---

## 10. UI/UX direction (HBO Max feel)

- **Dark, cinematic** default theme; content is the hero, chrome recedes.
- Large backdrop imagery, subtle gradients/blur behind text for legibility.
- Horizontal poster **rails** with smooth momentum scrolling; snappy focus/scale on hover/focus (crucial for TV D-pad later).
- Generous spacing, one clear primary action per screen, minimal nested menus.
- Motion: gentle hero cross-fades, shared-element-style transitions from poster → detail.
- Typography: one strong display face for titles + a clean UI face for metadata.
- Design the component library **focus-aware from the start** so Android TV (Phase 3) reuses it rather than forking.

---

## 11. Roadmap

**Phase 0 — Foundations**
Project setup, source abstraction, Xtream + M3U ingestion, catalog cache, account onboarding.

**Phase 1 — MVP (mobile, VOD-first)**
Home, Movies, Series (season/episode), detail pages, media_kit player with audio/subtitle
selection, resume/continue-watching, language preferences, favorites, settings. Android build first.

**Phase 2 — Live + polish**
Live TV + EPG guide, unified search, autoplay-next, PiP, Laravel sync backend, iOS distribution.

**Phase 3 — Android TV**
Leanback/D-pad UI layer, TV-optimized player controls, Chromecast (optional).

---

## 12. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Provider/panel inconsistency | Defensive parsing; never crash on bad rows; per-source quirks isolated in Source classes. |
| Large catalogs (perf) | TTL cache, background refresh, virtualized lists, lazy images. |
| Codec/stream edge cases | libmpv (media_kit) covers the vast majority; surface clear playback errors + retry. |
| iOS sideloading friction | Plan cert/TestFlight early; ship Android first to unblock. |
| EPG timezones | UTC storage + display offset; validate against a DST boundary. |
| Sync conflicts | Last-write-wins by UTC `updated_at`; local always source of truth. |

---

## 13. Open questions

1. ~~Working title / app name~~ — settled 2026-08-18: **Dawn Player**. The bundle id stays `com.example.aurora` so installed copies update in place instead of starting with an empty database.
2. Preferred DB: drift vs isar (both fine; drift = SQL-native, isar = object store).
3. Riverpod vs Bloc (Riverpod assumed).
4. Is Chromecast wanted, or is Android TV enough for the big-screen case?
5. Any need for adult-content hiding/PIN, or skip entirely?
