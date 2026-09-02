# Store listing — source of truth

Everything that goes into the Play Console and App Store Connect, written down once so the
two listings say the same thing and a resubmission does not become an archaeology exercise.

Keep this in step with three other places: `site/privacy.html`, `ios/Runner/PrivacyInfo.xcprivacy`,
and the Data safety form in the Play Console. If the app's behaviour changes, all four change.

---

## 1. Identity

| | |
|---|---|
| Store name | **Dawn Player** |
| Android application id | `com.dawnplayer.app` |
| iOS bundle identifier | `com.dawnplayer.app` |
| Version at first submission | `1.0.0` (build `1`) — `pubspec.yaml` `version:` |
| Developer contact | `support@dawnplayer.com` — **must be receiving mail before submission**, Play shows it publicly |
| Privacy policy URL | `https://dawnplayer.com/privacy.html` |
| Support URL | `https://dawnplayer.com/support.html` |
| Marketing URL | `https://dawnplayer.com` |

The internal Kotlin namespace stays `com.example.aurora`. That is invisible to users and to both
stores, and renaming it would churn the Cast provider class path for nothing.

---

## 2. The reviewer demo problem, and its solution

Both stores require working credentials for anything behind a login. For an IPTV player that is a
trap: handing a reviewer a real subscription puts copyrighted third-party channels in front of
App Review, which is precisely what triggers **guideline 5.2.3** (proof of rights to content).

**Do not give reviewers a real provider.** Use the mock panel already in the repo.

`tool/mock_xtream.php` is a complete Xtream Codes panel whose stream URLs redirect only to legal,
publicly available sources — Apple's multi-audio/subtitle HLS sample, DW English and Red Bull TV
(both free-to-air), and the Blender Foundation's Big Buck Bunny and Sintel, both CC-BY. It speaks
enough of `player_api.php` for the app's full feature set: auth, categories, live, VOD, series,
and short EPG.

The films are the full ten-minute Big Buck Bunny and the 52-second Sintel trailer, not the
ten-second clips this started with. Length is not cosmetic: a "film" that ends before you have
finished reading its title reads as a broken app to anyone reviewing it. They are also *named*
after themselves, so the catalogue says what it serves.

**No real titles in the demo catalogue.** The panel has a `MOCK_CANON=1` mode that fills it with
real award winners — `Oppenheimer 2023 4K`, `Breaking Bad` — so the discovery rails have something
to resolve against. That is useful on a laptop and indefensible anywhere else: a demo library
advertising those titles to App Review *is* the 5.2.3 accusation, made by us, on our own demo
account. It is off by default, `deploy/demo/index.php` forces it off again, and it was caught in a
store screenshot reading "Oppenheimer 2023 4K" over a cartoon rabbit.

The cost is that the home screenshot has no Award Winners rails, because nothing in the demo
catalogue is an award winner. Continue Watching carries that screen instead.

Deploy it at a stable public URL, e.g. `https://demo.dawnplayer.com`, and give both stores:

```
Server:   https://demo.dawnplayer.com
Username: aurora
Password: test
```

This is a strictly better review posture than a real line. The reviewer sees every feature working,
and everything they can play is demonstrably licence-free — which turns the 5.2.3 question from an
accusation into a non-issue. Keep the endpoint up for as long as the app is listed; review happens
again on every update.

---

## 3. Google Play

### 3.1 Store listing

**App name** (30 max) — 11 chars:

```
Dawn Player
```

**Short description** (80 max) — 73 chars:

```
Play the Xtream Codes or M3U line you already pay for. Resume that works.
```

**Full description** (4000 max):

```
Dawn Player is a player for the IPTV line you already have — not a provider. Point it at your
own Xtream Codes login or M3U playlist and it turns a wall of unsorted channels into something
that behaves like a streaming service.

It ships no channels, no films and no series. You bring the source.

WHAT IT FIXES

Playback that holds. Built on libmpv, the engine behind mpv and VLC, rather than the system
player. It handles the awkward codecs and odd containers that IPTV lines are full of, and it
recovers from a stalled stream instead of dropping you back to a grid.

Resume that works. Every film and episode remembers where you stopped, and the home screen puts
it back in front of you. Not approximately — to the second.

Languages it learns. Choose an audio track or a subtitle language once and Dawn Player applies
it to everything you open afterwards. No more setting the same language on every single episode.

A catalogue worth browsing. Films and series get posters, synopses and seasons laid out properly.
Add your own free TMDB key and gaps in your provider's artwork fill themselves in.

Your playlist, your order. Providers name groups badly and order them worse. Hide what you never
watch, rename what is misnamed, and drag the rest into an order that suits you. Your changes
survive a catalogue refresh.

A programme guide you can read. Your provider's EPG in a proper grid, with now-and-next on every
channel and a jump straight to what is on.

Search that finds things. One search box across live channels, films and series.

BUILT FOR TELEVISION TOO

The same app runs on Android TV and Google TV, with its own home-screen banner and full
remote-control navigation. On Android you can also cast to a Chromecast on your network.

PRIVATE BY CONSTRUCTION

No account, no sign-up, no analytics, no advertising, no tracking. Your credentials live in your
device's secure credential store, your watch history stays on the device, and streams travel
directly from your provider to you. There is no server of ours in the path — read the privacy
policy and see how short it is.

Optionally, sync your history and preferences between your own devices by pointing the app at a
server you run yourself. Off by default.

WHAT YOU NEED

An Xtream Codes login or an M3U playlist URL from a provider of your own choosing. Dawn Player
cannot supply one, and is not affiliated with any provider.

Some artwork and metadata from TMDB. This product uses the TMDB API but is not endorsed or
certified by TMDB.
```

### 3.2 Categorisation and declarations

| Field | Answer |
|---|---|
| App category | Video Players & Editors |
| Tags | Video player, Streaming |
| Contains ads | **No** |
| In-app purchases | **No** |
| Target audience | 18+ only. Do **not** tick any age band below 18 — the app plays unfiltered third-party content, and claiming a younger audience pulls in Families policy and Play's designed-for-children rules. |
| Ads / Designed for Families | Not applicable, given 18+ |
| Government app | No |
| Financial features | None |
| News app | No |
| Data safety | See §3.3 |
| Content rating | See §3.4 |

### 3.3 Data safety form

The honest answers, which are unusually simple because the app has no backend of ours.

**Does your app collect or share any of the required user data types?** → **No.**

Play's definitions make that answer correct rather than optimistic: "collect" means transmitted off
the device *to you or a third party you engage*. The app has no such transmission. Credentials go
only to the user's own provider to authenticate; the optional sync target is a server the user
supplies. Neither is a party the developer engages.

Then:

| Question | Answer |
|---|---|
| Is all user data encrypted in transit? | Provide the nuance: the app uses HTTPS wherever the user's provider offers it, but many IPTV providers serve only plain HTTP and the app must permit that to work at all. Declare accordingly rather than claiming blanket encryption. |
| Do you provide a way to request data deletion? | Yes — uninstall removes everything; per-provider removal in Settings → Accounts. Point the deletion URL at `https://dawnplayer.com/privacy.html#deleting-your-data`. |
| Committed to Play Families policy | No |
| Independent security review | No |

If Play's reviewer pushes back because the app *reads* credentials, the distinction to state is
storage versus collection: the credentials never reach a developer-controlled endpoint.

### 3.4 Content rating (IARC questionnaire)

Answer the questionnaire honestly and expect a mature rating. The load-bearing question is whether
the app gives access to content the developer does not control or filter — for an IPTV player the
answer is yes.

- Category: **Utility / Productivity / Communication** (it is a player, not a game)
- Does the app allow users to access uncontrolled/unfiltered content from the internet? → **Yes**
- User-generated content or sharing between users? → No
- Violence / sexuality / profanity / drugs authored by the app? → No to all — the app authors none

Expect roughly **Mature 17+ / PEGI 18**. Do not try to argue it down; a rating that does not match
unfiltered content access is a policy violation, and a high rating costs nothing here.

### 3.5 The 12-tester gate

This account is new and personal, so production access requires a **closed test with at least 12
testers opted in continuously for 14 days**, and since 2026 Google also checks the testers actually
used the app. Consequences worth planning around:

- The 14-day clock starts only once the closed-test release is **approved** *and* 12 testers have
  opted in. Recruit first, then count.
- Testers must stay opted in for the whole period. Someone who drops out and rejoins resets to zero.
- So: create the account and get a build into closed testing as early as possible. It is the
  longest pole in the schedule and it is pure waiting.
- Registering as an **organization** account instead (requires a D-U-N-S number) is exempt from this
  gate entirely. Worth a moment's thought if a business entity is available.

### 3.6 Android TV form factor

Add the TV form factor as a **separate declaration on the same app** — the AAB already carries the
leanback launcher intent, `touchscreen android:required="false"` and a 320×180 `tv_banner`, so one
bundle serves phone and TV.

The TV checklist is reviewed separately and more strictly than the phone listing. Against its
requirements the app already stands up:

| TV requirement | State |
|---|---|
| App bundle with TV launcher intent | Done — `LEANBACK_LAUNCHER` category in the manifest |
| No required touchscreen | Done — `touchscreen android:required="false"` |
| Localised 320×180 launcher banner | Done — `res/drawable-xhdpi/tv_banner.png`, `android:banner` set |
| Five-way D-pad navigation | Done — `_tvShell` in `app_shell.dart`: a hand-built focus rail (Material's `NavigationRail` cannot take D-pad focus), directional key handling, and post-frame focus hand-off across go_router branches |
| Correct Back behaviour | Done — `PopScope` in `player_screen.dart`, gated on where focus sits |
| Media keys | Done — play/pause/stop, rewind and fast-forward, plus `select`/`enter`/`space`/`gameButtonA` for OK |
| Landscape layout | Done — TV shell is a landscape rail-plus-content composition |
| Overscan-safe margins | Player already inset; the browse shell was **not** until `tvOverscan` was applied to `_tvShell` |
| 64-bit + 16 KB page sizes | Verified in the built bundle: `arm64-v8a` present, all `LOAD` alignments 0x4000 or 0x10000 |
| Touch-only affordances hidden | Cast is already suppressed on TV (`_castAvailable` is false there). The player's brightness and seek drag gestures remain registered but are simply unreachable without a touchscreen |

What is genuinely outstanding for the TV listing is therefore **verification, not construction**:
run it on an Android TV emulator or a real Streamer, walk every screen with the D-pad only, and
capture the 1920×1080 screenshots and 1280×720 banner the listing needs. `DAWN_FORCE_TV=true`
exercises the TV shell on a handheld emulator without downloading a TV system image.

---

## 4. App Store Connect

### 4.1 Listing

**App name** (30 max):

```
Dawn Player
```

**Subtitle** (30 max) — 29 chars:

```
Your own IPTV line, done well
```

**Promotional text** (170 max):

```
Point it at the Xtream Codes or M3U line you already pay for: playback that holds, resume to the
second, and audio and subtitle languages it learns once and remembers.
```

**Keywords** (100 max, comma-separated, no spaces after commas) — 92 chars:

```
iptv,m3u,xtream,playlist,epg,live tv,player,subtitles,chromecast,streaming,libmpv,vod,series
```

**Description**: reuse the Play full description from §3.1. It is within Apple's 4000-character
limit and needs no changes — Apple has no separate short-description field.

**Age rating**: answer the questionnaire honestly and expect **17+**. The decisive question is
*Unrestricted Web Access* — the app loads arbitrary user-supplied stream and playlist URLs, so the
answer is yes.

**Export compliance**: already answered in the binary. `ITSAppUsesNonExemptEncryption = false` is
set in `ios/Runner/Info.plist`, so uploads no longer stop to ask.

### 4.2 App Privacy (nutrition labels)

Select **Data Not Collected**. This mirrors `NSPrivacyCollectedDataTypes` being an empty array in
`ios/Runner/PrivacyInfo.xcprivacy`, and both must stay in agreement.

### 4.3 App Review notes — paste verbatim

This is the single most important field on the submission. It pre-empts 5.2.3 instead of waiting to
be accused, and it explains the ATS exception before a reviewer finds it and assumes the worst.

```
WHAT THIS APP IS

Dawn Player is a media player, not a content service. It ships with no channels, films or series
and has no catalogue of its own. It is unusable until the user supplies their own Xtream Codes
credentials or M3U playlist URL from a provider they have chosen and pay for independently. The
relationship is the same as a web browser to a website, or VLC to a video file.

We do not host, provide, resell, aggregate, index or recommend any content. We have no business
relationship with any content provider and receive no revenue from any. There is no in-app
discovery of providers, no directory of playlists, and no way to obtain content through the app.

DEMO ACCOUNT — LEGAL CONTENT ONLY

The demo credentials below connect to a test panel we operate that serves only legal, publicly
available streams: Apple's own sample HLS stream, DW English and Red Bull TV (both free-to-air),
and the Blender Foundation's Big Buck Bunny and Sintel (both Creative Commons Attribution).
Nothing reachable through these credentials is copyrighted material we lack the right to make
available.

  Server:   https://demo.dawnplayer.com
  Username: aurora
  Password: test

To review: launch the app, tap Add account, choose Xtream Codes, enter the three values above,
and wait for the catalogue to load. Live channels, films, series, the programme guide, search and
resume are all exercisable from there.

WHY THE APP TRANSPORT SECURITY EXCEPTION IS PRESENT

Info.plist sets NSAllowsArbitraryLoads. This is required, not convenient: the app plays streams
from server addresses the user types in, and a large share of IPTV providers still serve over
plain HTTP. Without the exception those streams fail silently and the app cannot perform its
only function. We control none of these hosts, so a domain allowlist is not possible. The app
uses HTTPS whenever the user's provider offers it. No data of ours travels over these
connections — the app has no backend.

PRIVACY

No accounts, no analytics, no advertising, no tracking, no crash reporting, and no server
operated by us. Credentials are stored in the Keychain. Watch history stays on the device.
Full detail: https://dawnplayer.com/privacy.html

METADATA ATTRIBUTION

Artwork and synopses are fetched from TMDB only if the user supplies their own TMDB API key, and
are off by default. The bundled list of award-winning titles derives from Wikidata (CC0) and
Wikipedia (CC BY-SA 4.0) and contains titles and years only — no artwork and no content. It is
used solely to recognise titles that already exist in the user's own playlist.
```

### 4.4 Signing and upload without a Mac

Development is on Windows, so signing and upload run on the GitHub Actions macOS runners.
`.github/workflows/ios-release.yml` does the whole job — import certificate, install profile, build,
validate, upload to TestFlight. It is `workflow_dispatch` only, because a release is a decision.

The certificate is the part people assume needs a Mac. It does not: a distribution certificate is
just an X.509 cert issued against a certificate signing request, and OpenSSL on Windows produces the
CSR perfectly well. Keychain Access is a convenience, not a requirement.

**Everything below is one-time, and none of it can start before the paid membership exists** — the
certificate has to be issued against a real team.

#### Step 1 — Enrol and register the identifiers

1. Enrol at <https://developer.apple.com/programs/> ($99/yr). Individual enrolment shows your own
   legal name as the seller on the App Store; an organization needs a D-U-N-S number.
2. Certificates, Identifiers & Profiles → **Identifiers** → **+** → App IDs → App → register
   `com.dawnplayer.app`. No capabilities need enabling: background audio is declared through
   `UIBackgroundModes` in `Info.plist`, not as an App ID capability, and Keychain access needs no
   entitlement unless you share a keychain group, which the app does not.
3. Note your **Team ID** from the Membership page → secret `IOS_TEAM_ID`.

#### Step 2 — Distribution certificate, from Windows

```powershell
# A 2048-bit key and a CSR. Keep the .key file — it is the private half of the
# certificate, and losing it means revoking and reissuing.
openssl genrsa -out dawnplayer-dist.key 2048
openssl req -new -key dawnplayer-dist.key -out dawnplayer-dist.csr `
  -subj "/CN=Dawn Player Distribution/C=NL"
```

Upload `dawnplayer-dist.csr` at Certificates → **+** → **Apple Distribution**, then download the
issued `distribution.cer` and bundle it with its private key into a `.p12`:

```powershell
# Apple hands back DER; PKCS#12 wants PEM.
openssl x509 -inform DER -in distribution.cer -out distribution.pem

# -certfile adds Apple's intermediate so codesign can build the full chain even
# if the runner image ever ships without it.
curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
openssl x509 -inform DER -in AppleWWDRCAG3.cer -out AppleWWDRCAG3.pem

openssl pkcs12 -export -legacy `
  -inkey dawnplayer-dist.key -in distribution.pem -certfile AppleWWDRCAG3.pem `
  -name "Apple Distribution" -out dawnplayer-dist.p12
```

The export password becomes secret `IOS_DIST_CERT_PASSWORD`. Use `-legacy` on OpenSSL 3.x: without
it the archive uses AES-256 encryption that macOS's `security import` cannot read, which surfaces as
a completely unhelpful "MAC verification failed".

#### Step 3 — Provisioning profile

Profiles → **+** → Distribution → **App Store Connect** → select the `com.dawnplayer.app` App ID and
the certificate from step 2 → download the `.mobileprovision`.

#### Step 4 — App Store Connect API key

Users and Access → Integrations → App Store Connect API → **+**, role **App Manager**. Download the
`AuthKey_XXXXXXXXXX.p8` — Apple lets you download it exactly once. Note the **Key ID** and the
**Issuer ID** shown above the table.

This is preferred over an Apple ID with an app-specific password: it survives password changes and
needs no 2FA interaction on a headless runner.

#### Step 5 — Turn the three files into secrets

GitHub secrets must be single-line base64. Do **not** use `certutil -encode`, which wraps the output
in BEGIN/END headers and line breaks:

```powershell
# Copies each value straight to the clipboard, one at a time.
[Convert]::ToBase64String([IO.File]::ReadAllBytes("dawnplayer-dist.p12"))       | Set-Clipboard  # IOS_DIST_CERT_P12
[Convert]::ToBase64String([IO.File]::ReadAllBytes("dawnplayer.mobileprovision")) | Set-Clipboard  # IOS_PROVISIONING_PROFILE
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))     | Set-Clipboard  # ASC_KEY_P8
```

Full secret list: `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE`,
`IOS_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.

Store `dawnplayer-dist.key`, the `.p12` and the `.p8` somewhere durable and outside the repo, next to
the Android upload keystore. Losing the `.p8` means generating a new API key; losing the `.key`
means revoking and reissuing the certificate.

#### Step 6 — Create the app record, then ship a build

In App Store Connect → Apps → **+** → New App: platform iOS, name **Dawn Player**, primary language,
bundle ID `com.dawnplayer.app`, and any SKU you like (it is internal — `dawnplayer-ios` is fine).

Then run the **iOS Release** workflow with a `build_number`. It validates before uploading, which
catches the cheap rejections — missing icon, bad Info.plist key, wrong bundle id — in seconds rather
than after a long upload. Build numbers must strictly increase per version string, so treat
`git rev-list --count HEAD` as the source of truth if you ever lose track.

Both `--validate-app` and `--upload-app` require the app record to exist first. Run the workflow
with `submit_to_testflight` unchecked until it does: that exercises the entire signing path and
produces a signed IPA artifact without touching App Store Connect.

### 4.5 Filling the listing without retyping it

`tool/asc.mjs` writes the listing into App Store Connect over its API, from
`tool/asc-listing.json` — the machine-readable mirror of §4.1 and §4.3 above. Change wording in one
and change it in the other; the prose here is what a human reads, the JSON is what gets pushed.

```powershell
$env:ASC_ISSUER_ID = "<Users and Access → Integrations → Issuer ID>"
node tool/asc.mjs status          # what ASC currently holds
node tool/asc.mjs push --dry-run  # what would change
node tool/asc.mjs push            # name, subtitle, description, keywords, urls,
                                  # review notes, demo credentials, age rating
node tool/asc.mjs shots build/screenshots   # upload the 6.9" set, in page order
```

It authenticates with the same `AuthKey_*.p8` the release workflow uses (`ASC_KEY_ID` defaults to
`77QHZJDRNT`, the key file to `%USERPROFILE%\dawnplayer-ios\`). ES256 tokens must carry a raw r‖s
signature — Node signs DER by default and Apple answers a DER-signed token with a bare 401, which
is a long afternoon if you do not know it.

It deliberately does **not** submit for review, set pricing, or accept agreements. Those carry legal
attestations that belong to a person clicking them.

#### Troubleshooting: "No development certificates available to code sign app"

Hit on the first signed build, and misleading — it appears even with a valid Apple Distribution
certificate and App Store profile installed. The cause is in Flutter itself
(`flutter_tools/lib/src/ios/code_signing.dart`): when the Xcode project has no `DEVELOPMENT_TEAM`
build setting, Flutter searches the keychain for a *development* identity and fails hard if it finds
none, and a distribution certificate never matches that search.

Fixed by setting `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE = Manual`,
`CODE_SIGN_IDENTITY[sdk=iphoneos*] = "Apple Distribution"` and `PROVISIONING_PROFILE_SPECIFIER` on
the **Runner target's** Release configuration. Target level matters: the Flutter template puts
`CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` at *project* level, and project settings
outrank `Release.xcconfig` — so an xcconfig override looks right and silently loses.

`ios-unsigned.yml` is unaffected, because `--no-codesign` passes `CODE_SIGNING_ALLOWED=NO` on the
xcodebuild command line, which outranks everything in the project.

---

## 5. Graphic assets

None of these exist yet. Dimensions are exact requirements, not suggestions.

### Google Play

| Asset | Spec | Notes |
|---|---|---|
| App icon | 512×512 PNG, 32-bit, no alpha | Generate from `assets/icon/dawn_icon.png` |
| Feature graphic | 1024×500 PNG/JPG, no alpha | Required. Shown at the top of the listing; do not put small text in it |
| Phone screenshots | 2–8, 16:9 or 9:16, min 320px, max 3840px | Home, catalogue, player, programme guide, settings |
| 7" tablet | Optional | Skip for launch |
| 10" tablet | Optional | Skip for launch |
| **TV banner** | **1280×720 PNG/JPG, no alpha** | Required for the TV form factor. Distinct from the in-APK 320×180 `tv_banner.png` — that one is the launcher tile, this one is the store listing |
| **TV screenshots** | **At least 3, 1920×1080 PNG/JPG, no alpha, landscape** | Must show the TV UI, not a stretched phone UI. Blocked on the D-pad work |

### App Store

| Asset | Spec | Notes |
|---|---|---|
| App icon | 1024×1024 PNG, no alpha, no rounded corners | Ships inside the binary from `assets/icon/dawn_icon.png`; App Store Connect reads it from there |
| 6.9" iPhone | 1320×2868 or 2868×1320 | The only screenshot size still required. Produced by the workflow below |
| 6.5" iPhone | 1242×2688 | No longer required — App Store Connect scales the 6.9" set down |
| 13" iPad | 2064×2752 | Not applicable. `TARGETED_DEVICE_FAMILY = "1"`, so the app is iPhone-only and ASC does not ask |

Screenshots need a running app on the right form factor, so they come after the emulator/device
pass, not before. Use the mock panel from §2 to populate them — it gives a full, realistic
catalogue with legal artwork, and it means no screenshot ever shows a real provider's channel list.

### 5.1 How the iPhone screenshots are produced

The development iPhone is a base iPhone 17 — 6.3", 1206×2622 — and the 6.9" slot takes only
1320×2868. Rather than composite real captures into designed frames (artwork to redo by hand every
release), `.github/workflows/ios-screenshots.yml` captures them on a simulator that is natively
that size.

It runs `tool/mock_xtream.php` on the runner itself, boots an iPhone Pro Max simulator, overrides
the status bar to Apple's 9:41 convention, and launches the app with `--dart-define=DAWN_TOUR=true`.
That switch turns on `lib/tour/screenshot_tour.dart`, which seeds the demo account, caches the
catalogue and the guide, leaves three films part-watched so Continue Watching is not an empty row,
then walks home → live → guide → films → a series → the player, printing a marker line at each stop.

The capture itself happens outside Flutter, via `xcrun simctl io … screenshot`, because a
Flutter-side screenshot renders only the Flutter layer — the player would come out as a black
rectangle where the video is. The job then asserts every PNG is exactly 1320×2868 and fails if one
is not, which is the check that would otherwise happen as a rejection.

The tour is a capture harness, not a test suite: nothing asserts, and a stop that throws is logged
and skipped so the rest of the run still yields its images. `screenshotTourEnabled` is a
`const false` in every normal build, so all of it compiles out of a release.

The player shot deliberately plays Big Buck Bunny rather than a live channel: it is Creative
Commons, so the one screenshot containing video contains nothing anybody else owns, and a film also
puts the seek bar in frame, which live playback hides.

---

## 6. Open items before submission

- [x] `support@dawnplayer.com` — Cloudflare Email Routing configured 2026-09-01; `dawnplayer.com`
      MX now answers `route1/2/3.mx.cloudflare.net`. Send it a test mail from outside and confirm it
      lands before submitting; receiving is enough for both stores, sending needs a real mailbox
- [x] `dawnplayer.com` DNS — already resolving to GitHub Pages (185.199.108-111.153) before any of
      this work; nothing to configure
- [x] `site/` merged to `plexus/site` and deployed 2026-08-26 (run 32977270235). Verified live:
      `/privacy.html` and `/support.html` both 200, and `robots.txt` now serves the Allow rules.
      Worth noting the blanket `Disallow: /` had been live and effective on the custom domain, so
      Play's privacy-policy fetch would have failed had this not been caught
- [ ] Mock panel deployed at `https://demo.dawnplayer.com`. The web root and a click-by-click Ploi
      runbook are in `deploy/demo/` — verified locally (60 live / 200 films / 24 series, the
      `?count=` overrides stripped, streams redirecting to the real CDNs). What is left is the Ploi
      site, the Cloudflare `A` record and Let's Encrypt, all of which are dashboard work
- [ ] Play developer account registered (start the 12-tester clock early — §3.5)
- [x] Apple Developer Program membership active (2026-08-31). Team `XTBG48BLG7`
- [x] iOS signing works end to end. All 7 secrets loaded; run 33371032544 produced a **signed**
      IPA (31.5 MB) whose `embedded.mobileprovision` is `Dawn Player App Store` for
      `XTBG48BLG7.com.dawnplayer.app`, `get-task-allow false`, no provisioned devices —
      a genuine App Store distribution build. Certificate valid to 2027-08-31
- [x] **App Store Connect app record** created 2026-09-01
- [ ] Note: the legacy `com.example.aurora` App ID still exists in the portal from sideloading days.
      Harmless; rename its description so it cannot be picked by mistake when issuing profiles
- [x] iOS build verified on Xcode (run 32967296683, `plexus/apps`). The built `Info.plist` reads
      `com.dawnplayer.app`, `UIDeviceFamily [1]`, `ITSAppUsesNonExemptEncryption false`,
      `MinimumOSVersion 13.0`, version `1.0.0 (1)`; the app-level `PrivacyInfo.xcprivacy` is present
      in `Runner.app`, and all six bundled fonts plus both OFL texts ship in `flutter_assets`
- [x] iOS screenshots done 2026-09-02 — six captured (home, live, guide, films, series, player) and
      uploaded in page order. Note there is **no `APP_IPHONE_69`** display type in the API: 6.9"
      screenshots belong to `APP_IPHONE_67`, which the web UI labels *iPhone 6.9" Display*
- [x] Listing text pushed to ASC 2026-09-01 via `tool/asc.mjs push`, and read back: name, subtitle,
      privacy URL, a 2305-character description, keywords, promotional text, support and marketing
      URLs, and the age-rating questionnaire (`unrestrictedWebAccess: true`). Issuer ID
      `9b8c74b9-d412-4772-8500-b5dde7e6b3d5`
- [x] Version string corrected **1.0 → 1.0.0**. The record Apple created said `1.0` while both
      binaries say `1.0.0`; a build is only offered for a version whose string matches its
      `CFBundleShortVersionString`, so the build picker would have been empty with no explanation
- [ ] **Review details** — blocked on a contact phone number. Fill `contactPhone` in
      `tool/asc-listing.json` and re-run `node tool/asc.mjs push`; the script refuses to write a
      half-filled review detail, because one that looks answered is worse than one that is empty
- [ ] Left in the web UI by design, because they carry attestations a script should not make:
      pricing (Free), availability, the App Privacy nutrition label (**Data Not Collected**),
      attaching build 2, and Submit
- [x] Minimum iOS raised 13.0 -> 15.0, clearing Apple warning 90068 (uploads below 15.0 are
      refused from Spring 2027). No reach lost: iOS 15 covers the same iPhone generations as 13
- [x] Launch screen replaced. It was the Flutter placeholder — pure white background and a 1x1
      transparent pixel — so every cold start flashed white before a near-black app. Now #0B0D12
      with the icon at 120pt, alpha rounded corners
- [x] Builds uploaded: build 1 (2026-08-31, `state=VALID` at Apple) and build 2 with both fixes
      above. Build 2's validation reports **no errors and no warnings** at all
- [ ] `flutter build ios` warns that plugins not adopting Swift Package Manager (media_kit_video,
      media_kit_libs_ios_video) "will become an error in a future version of Flutter". Not urgent,
      but it dates the toolchain pin
- [x] Signed AAB produced and verified — signed `CN=Dawn Player, O=Laffort, C=NL`, ABIs
      arm64-v8a / armeabi-v7a / x86_64, all native libs stripped and 16 KB aligned.
      `build/` in this worktree is now a junction to `D:\dev\flutter-build\streamer-aurora-apps`
      because C: had 2.2 GB free and the build needs more
- [ ] Graphic assets produced (§5)
- [ ] **TV verification pass** — the D-pad implementation exists (§3.6); what it has not had is a
      walk-through on a TV target, which is also how the TV screenshots get taken
- [ ] Flutter's `strip debug symbols` post-step fails on this box and makes `flutter build
      appbundle` exit 1 even though Gradle succeeded and every shipped `.so` is already stripped.
      Harmless for the artifact, but it will fail a CI gate — worth fixing before wiring release CI
- [x] Fonts bundled. Inter (400/500/600/700) and Outfit (600/700) ship as static assets and the
      `google_fonts` dependency is gone, so the app makes no font-CDN call at all — the Google Fonts
      row is out of the privacy policy and a cold first launch with no network renders correctly.
      OFL 1.1 texts ship in `assets/licenses/` and are registered with `LicenseRegistry`. Cost:
      about 1.4 MB of assets
