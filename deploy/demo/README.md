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

1. **Cloudflare DNS** — add an `A` record for `demo` pointing at the laffort server's IP.
   Leave it **DNS only** (grey cloud). Proxying buys nothing here and complicates the Let's Encrypt
   HTTP-01 challenge.
2. **Ploi → Sites → New site**
   - Domain: `demo.dawnplayer.com`
   - Project directory / web directory: `/deploy/demo`
   - PHP version: 8.3 or 8.4
   - Do **not** pick the Laravel installer.
3. **Ploi → the new site → Repository** — install `martijnlaffort/streamer-aurora`, branch
   `plexus/apps`. The whole repo is checked out and `index.php` finds the panel at `tool/`.
   Updating the demo later is then one click on *Deploy*.

   If Ploi's GitHub connection cannot see the private repo, upload by hand instead: copy the four
   files in this directory **plus `tool/mock_xtream.php`** into the site's web root, all in one
   flat directory. `index.php` falls back to `./mock_xtream.php` when the repo layout is absent.
4. **Ploi → SSL → Let's Encrypt** for `demo.dawnplayer.com`.
5. Leave the site's deploy script alone — there is nothing to build, no composer install, no
   artisan. It is four PHP files.

This is a new site on a box that already serves live sites. Ploi isolates sites per nginx server
block and per pool, so adding one changes nothing about the others — but the click path is yours,
per the standing rule about that server.

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
