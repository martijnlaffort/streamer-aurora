# demo.dawnplayer.com — the reviewer demo panel

App Review and Play review both need working credentials, and handing either one a real IPTV
subscription is what triggers Apple guideline 5.2.3. This directory is the web root of a public
deployment of `tool/mock_xtream.php`: a complete Xtream Codes panel whose streams resolve only to
Apple's sample HLS feed, DW English, Red Bull TV and Big Buck Bunny. Every feature is
demonstrable and nothing reachable through it is licence-encumbered.

```
Server:   https://demo.dawnplayer.com
Username: aurora
Password: test
```

Keep it up for as long as the app is listed — review happens again on every update.

## What is in here

| File | Why |
|---|---|
| `index.php` | Web root. Pins the catalogue size, removes the `?count=` overrides, loads the panel |
| `player_api.php`, `xmltv.php` | nginx sends any `*.php` URI straight to PHP-FPM, so `try_files` never routes them to `index.php`. These two have to exist as real files or FPM answers "Primary script unknown" |
| `robots.txt` | Disallow everything |

`/playlist.m3u` and the `/live/…`, `/movie/…`, `/series/…` stream URLs have no `.php` extension, so
nginx's default `try_files $uri $uri/ /index.php?$query_string` hands them to `index.php` on its own.

Requires **PHP 8.0 or newer** (the panel uses `match` and `str_contains`) and `allow_url_fopen=On`,
which is the default — the panel proxies HLS *playlists* so a player resolves variant URLs against
the real CDN. Only playlists are proxied; media itself is a 302 straight to the origin, so this
carries no meaningful bandwidth.

## Deploying on Ploi

The whole thing is five small files and a git checkout — 3.5 MB of repo, no database, no queue, no
build step. Most of the work is making sure Ploi does not try to do more than that.

### 1. Cloudflare DNS

Add an `A` record: name `demo`, value the laffort server's IPv4 (Ploi shows it on the server page).
**Proxy status: DNS only** — the grey cloud, not the orange one. Proxying buys nothing here, it
complicates the Let's Encrypt HTTP-01 challenge, and Cloudflare's terms are unfriendly to video
through the proxy.

Wait for `nslookup demo.dawnplayer.com` to answer before asking Ploi for a certificate.

### 2. Create the site

Ploi → your server → **Sites** → **Add site**:

| Field | Value |
|---|---|
| Domain | `demo.dawnplayer.com` |
| Project type | **PHP** — not Laravel, not Static HTML (see note below) |
| Web directory | `/deploy/demo` |
| PHP version | 8.3 or 8.4 |
| System user | leave as default |

**Project type matters.** The PHP template's nginx `location /` is
`try_files $uri $uri/ /index.php?$query_string;`, which is what routes `/playlist.m3u` and the
`/live/…`, `/movie/…`, `/series/…` stream URLs to `index.php`. The Static HTML template ends that
line in `=404` and every stream URL would 404. Check it under **Manage → NGINX configuration** if
in doubt.

Do not create a database, a queue worker, or a cron entry. There is nothing to schedule.

### 3. Install the repository

Site → **Repository**: provider GitHub, repository `martijnlaffort/streamer-aurora`, branch
`plexus/apps`. If Ploi offers "install composer dependencies", **untick it**.

The repo is private, so Ploi's GitHub integration has to be authorised for it. If it cannot see the
repo, Ploi shows a **deploy key** — paste that into GitHub → the repo → Settings → Deploy keys
(read access is enough).

### 4. Fix the deploy script before deploying

This is the step that bites. Ploi's generated script for a PHP site ends with something like
`composer install --no-interaction --prefer-dist --optimize-autoloader`, and this repo has no
`composer.json` — it is a Flutter app with a PHP file in it. Composer fails, and Ploi marks every
deploy as failed even though the files are fine.

Replace the whole script with:

```bash
cd /home/ploi/demo.dawnplayer.com
git pull origin plexus/apps
echo "demo panel deployed"
```

Then hit **Deploy**. Updating the demo later is that one button.

### 5. Certificate

Site → **SSL** → **Let's Encrypt** → request for `demo.dawnplayer.com`. It should issue in seconds
now the A record is live and unproxied.

### If Ploi cannot reach the private repo

Upload by hand instead. Copy into the site's web root, all in one flat directory:

```
index.php
player_api.php
xmltv.php
robots.txt
mock_xtream.php      <- copied from tool/mock_xtream.php
```

`index.php` looks for the panel two directories up first (the repo layout) and falls back to
`./mock_xtream.php`, so a flat directory works with no edits. The cost is that updating it means
uploading again.

### Notes on the server itself

This is a new site on a box that already serves live sites. Ploi isolates sites per nginx server
block and per PHP-FPM pool, so adding one changes nothing about the others — but the click path is
yours, per the standing rule about that server.

Two PHP settings the panel depends on, both defaults: `allow_url_fopen=On` (it proxies HLS
*playlists* so a player resolves variant URLs against the real CDN) and PHP **8.0 or newer** (it
uses `match` and `str_contains`).

## Verifying it before you put the credentials in front of a reviewer

```powershell
# Auth: expect "auth":1
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test"

# Wrong password: expect "auth":0
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=wrong"

# Categories, live channels, films, series
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test&action=get_live_categories"
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test&action=get_live_streams"
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test&action=get_vod_streams"
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test&action=get_series"

# EPG (XMLTV) — expect <tv> … </tv>
curl.exe -s "https://demo.dawnplayer.com/xmltv.php?username=aurora&password=test" | Select-Object -First 5

# A live stream: expect an HLS playlist body, not a redirect
curl.exe -s "https://demo.dawnplayer.com/live/aurora/test/1.m3u8" | Select-Object -First 3

# A film: expect 302 to test-videos.co.uk
curl.exe -s -o NUL -w "%{http_code} %{redirect_url}`n" "https://demo.dawnplayer.com/movie/aurora/test/1001.mp4"

# Overrides must be gone: this must NOT return 40000 channels
curl.exe -s "https://demo.dawnplayer.com/player_api.php?username=aurora&password=test&action=get_live_streams&lcount=40000" | Measure-Object -Character
```

Then add the account in the app itself — that is the only test that proves what the reviewer will
experience.

## Catalogue size

`index.php` pins 60 live channels, 200 films, 24 series. Live channels beyond the first three reuse
those three real streams round-robin, so every row in the list plays. Change the three `putenv`
lines if a screenshot wants a fuller or emptier catalogue.
