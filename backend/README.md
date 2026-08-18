# Dawn Player sync backend

A thin Laravel API that syncs **watch progress, favorites, and preferences**
across your devices (PRD §9). It is optional — Dawn Player is fully functional
without it; the app's repositories are local-first and treat this as a
drop-in reconciler.

Personal, single-user design: one user, one shared **Sanctum token** you paste
into each device. No login screens. Reconciliation is **last-write-wins by
UTC `updated_at`**.

## What's here

This folder is an **overlay** on a stock Laravel app — the files that are
specific to Dawn Player sync. Drop them into a fresh Laravel install:

```
backend/
  routes/api.php                                  # the API routes
  app/Models/{WatchProgress,Favorite,Preference}.php
  app/Http/Controllers/Api/{Progress,Favorites,Preferences}Controller.php
  app/Console/Commands/MakeSyncToken.php          # `php artisan aurora:token`
  database/migrations/2026_07_27_000001_create_sync_tables.php
```

## Deploy (Ploi / Hetzner)

```bash
# 1. Fresh Laravel + Sanctum
laravel new aurora-sync && cd aurora-sync
composer require laravel/sanctum
php artisan install:api          # publishes Sanctum, adds routes/api.php

# 2. Copy this folder's files over the fresh app (same paths).

# 3. Database (SQLite is plenty for one user; or point at MySQL in .env)
php artisan migrate

# 4. Mint a token to paste into the app
php artisan aurora:token
```

On Ploi: create the site, set the repo/deploy script to the above, point the
web root at `public/`, and add a Let's Encrypt cert so the app talks HTTPS.

## API

All routes require `Authorization: Bearer <token>` and live under `/api`.

| Method | Path | Purpose |
|---|---|---|
| GET  | `/api/progress?since=ISO8601` | changed progress since `since` |
| POST | `/api/progress` | upsert a batch `{entries:[…]}` (LWW) |
| GET  | `/api/preferences` | the prefs object (or null) |
| PUT  | `/api/preferences` | upsert prefs (LWW) |
| GET  | `/api/favorites` | all favorites |
| POST | `/api/favorites` | add `{content_key, added_at}` |
| DELETE | `/api/favorites/{contentKey}` | remove |

Times are ISO-8601 **UTC**. The server keeps the newer of two edits by
`updated_at`, so a stale device can't clobber a fresh one.

## In the app

Dawn Player → **Settings → Sync**: paste the base URL (e.g.
`https://sync.example.com`) and the token, toggle Sync on. It reconciles on
app open and via **Sync now**.
