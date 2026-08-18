# Dawn Player — website design system

The design for Dawn Player's public page, built before the site itself. Every file here is a
standalone HTML preview: open one in a browser and it renders on its own, no build step and no
shared stylesheet to resolve. They are also the cards published to the Claude Design project
"Aurora — Website", which is where this is meant to be reviewed.

## Why the design looks like this

The app already has a design system (`lib/core/theme/`), so the site inherits it rather than
inventing a second identity:

| Token | Value | Where it comes from |
|---|---|---|
| canvas | `#0B0D12` | `AppColors.background` |
| surface / elevated | `#12151C` / `#1A1E27` | `AppColors.surface`, `surfaceElevated` |
| accent | `#7C5CFF` | `AppColors.accent` — the violet of first light |
| accent alt | `#4FD1C5` | `AppColors.accentAlt` — the teal glow |
| text / secondary | `#F2F4F8` / `#9AA3B2` | `AppColors.textPrimary`, `textSecondary` |
| focus ring | `#FFFFFF` 2px | `AppColors.focusRing` |
| scrim | 3-stop bottom-up | `AppColors.scrim` |
| display / UI face | Outfit / Inter | `AppTypography` |

Three decisions worth knowing before editing anything:

1. **Dark only.** The app has no light theme and the PRD's direction is "content is the hero,
   chrome recedes". A light variant would be a different product.
2. **Flat surfaces with hairline borders, never shadows.** On a near-black canvas a 1px
   white-7% border separates things; a drop shadow just looks like a light-theme layout painted
   dark. Shadows appear only under device mockups.
3. **Focus is designed, not inherited.** The white ring shows up in the mockups and on every
   interactive element, because the same components run on a television with a D-pad.

## Files

```
tokens.css                  the values above, as CSS custom properties (the site will import this)
brand/dawn.html             THE MARK — sunrise + play, wordmark, dawn gradient, applied
brand/dawn-icon.html        1024×1024 app icon generator (render + screenshot)
foundations/color.html      swatches with usage + measured contrast
foundations/type.html       six type roles, Outfit + Inter
foundations/space.html      4pt space scale, radius scale, the three elevations
foundations/icons.html      the 23 icons the site needs, hand-drawn to match Material outlined
components/buttons.html     filled / tonal / ghost / link, sizes, states, chips
components/nav.html         at rest over artwork, scrolled, and the mobile sheet
components/feature-card.html  card anatomy + the 6-up grid
components/steps.html       the how-it-works track
components/spec-strip.html  under-the-hood table + the "what it isn't" panel
components/footer.html      lockup, attribution, fine print
sections/hero.html          ambient ribbon field, headline, phone bleeding off the fold
sections/fixes.html         the page's argument: three annoyance → answer panels
sections/spotlight.html     the two alternating copy+device blocks
mockups/phone-home.html     Home: hero, Continue Watching, Top 10, six-tab bar
mockups/phone-player.html   player overlay, live variant, subtitle selector
mockups/tv-guide.html       Android TV: D-pad rail, day grid, now-line, catch-up
```

## Where the page design lives now

**This project is the kit, not the page.** The whole-page design moved to a separate Claude Design
project, **"Aurora One-page Site"** (`fee7e40b-04e5-4a5d-bd55-c9edc7c2bab7`), file
`Aurora Website.dc.html`, which imports this kit under `_ds/aurora-website-<id>/`. That file is the
design of record, and the shipped site at `site/` implements it.

The `pages/landing.html` + `pages/landing-mobile.html` cards that used to live here were retired on
2026-08-14 — superseded, and keeping two page designs around invites building the wrong one.

Two things in this kit the newer design changed, so read the cards with that in mind:

- **Canvas.** The site lifts the canvas off near-black to a charcoal: `--bg #171C25`,
  `--surface #1F2530`, `--surface-2 #29313E`, line opacities .09/.17. Accents, type, spacing and
  radius are untouched, so every other card here still holds. `tokens.css` keeps the app's values;
  `site/styles.css` overrides those five.
- **Hero and nav.** `sections/hero.html` shows the earlier hero (one phone bleeding off the fold)
  and `components/nav.html` a burger sheet. The built hero is a television with the phone over its
  corner joined by a "same position, both screens" line, and under 820px the nav keeps only its
  "Get set up" CTA.

## Mockups, deliberately

No screenshots. Every device mockup is CSS and inline SVG built from the real widget structure
(`PosterCard`, the hero's eyebrow + Details/My List buttons + page dots, Continue Watching's
4px violet progress bar, the Top 10 rank numeral, the player's control row, the TV guide's
now-line). Artwork is abstract gradient and **every title is invented** — Harbourline, The Quiet
Coast, Ashfall, Nightfold, Vesper Bay, Halcyon. The site never shows a real catalogue, which
keeps someone's actual provider and library out of a public page.

Swap them for real screenshots later if you want; the frames are sized to take a 16:9 or 2:3
image without touching the layout.

## Voice

Plain, specific, faintly dry. Say what it does and why it was necessary. Claims are testable —
"saved every few seconds and on every exit", not "never lose your place". The honesty panel is
part of the design, not a disclaimer bolted on: no store listing, no content, no support desk.

Never: "revolutionary", "seamless", "powerful", exclamation marks, or any suggestion that Dawn Player
supplies channels.

## Fonts

Outfit and Inter load from Google Fonts. If that request is blocked the stack falls back to the
system UI face and no layout shifts. When the site is built, self-host both as woff2 — one less
third party, and it removes the fallback question entirely.

## The site that came out of this

`site/` — `index.html`, `styles.css`, `main.js`, `tokens.css`. Static, no framework, no build step,
deployable to any host including Ploi. Run it locally with `php -S localhost:8080 -t site` (or
`python -m http.server 8080 -d site`), or just open `site/index.html` — every path is relative and
nothing fetches, so `file://` works too.

Still outstanding: self-host Outfit and Inter as woff2 (one less third party, and it settles the
fallback question), and add an Open Graph image — the `og:` tags are there but point at nothing.
