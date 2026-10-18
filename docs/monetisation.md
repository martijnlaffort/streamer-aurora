# Monetisation — one payment, both platforms

A plan for putting some of Dawn Player behind a paywall without charging the same person twice and
without acquiring an account system. Nothing here is built. It is written down now because two
decisions get expensive if they are made late — where the entitlement lives, and what stays free.

Not urgent. 1.0 ships free; this is for the release after it.

---

## 1. Why cross-platform is the requirement, not a nice-to-have

TiviMate, the obvious comparison, sells a Premium subscription and never faces this problem: it is
Android and Android TV only, so one store holds every purchase a user could make.

Dawn Player's most likely user has an **iPhone and an Android TV**. That is not an edge case for this
app, it is the main case — the phone is where you browse and the television is where you watch, and
almost nobody buys both from the same store. Charging twice for that would read as a bug, and would
be the first thing in every review.

So: one purchase, honoured on both platforms. Everything below follows from that.

## 2. What the stores permit

Apple guideline **3.1.3(b), Multiplatform Services** is explicit: an app may let users access
features they acquired on another platform, **provided the same item is also available as an in-app
purchase within the app**. Google's payments policy governs purchases made *inside* the app, so
honouring an entitlement that already exists is equally fine.

What gets you rejected on both stores is **steering** — any nudge toward buying outside the app.
Not a link, not a hint, not a price comparison. Sell it through IAP on both stores and honour
either, and there is no conflict with either policy.

External purchase links have been permitted in some jurisdictions since 2025 (the US injunction, the
DMA in Europe) and the terms attached are still moving. **Do not build on that.** The design below
is indifferent to how it settles.

## 3. Product shape

Start with a **non-consumable lifetime unlock**, not a subscription.

- No renewal state to reconcile, no "is it still active" question on a device that has been offline
  for a month, no dunning, no churn.
- Apple scrutinises subscriptions harder (3.1.2 wants continuing value). A player that hosts nothing
  has a weaker story for a recurring charge than a service does.
- A subscription becomes honest later, if the sync backend turns into something we actually run for
  people rather than a thing they self-host.

TiviMate sells both. That is a reasonable end state; it is a bad starting state.

## 4. What goes behind it

The rule: **never gate something whose absence makes the free app look broken.** A free user must be
able to add their line, browse it, and watch it, with no nagging.

| Paid | Free, permanently |
|---|---|
| Multi-view (two live channels side by side) | One playlist, browse, playback |
| Timeshift / pause live TV | The programme guide and search |
| More than one playlist or account | Resume, and audio/subtitle language memory |
| Cross-device sync | Favourites, hide/rename/reorder groups |
| Programme reminders | Chromecast |
| TMDB artwork enrichment | Everything 1.0 shipped with |

**Grandfather everything in that last row.** Users forgive a paywall on new work and never forgive
losing something they already had. This is also why the table matters now rather than later: each
release that ships a feature free makes it harder to charge for.

## 5. Architecture

```
  iPhone                                     your server (aurora-sync)
  ──────                                     ─────────────────────────
  buys IAP
  StoreKit 2 gives a signed transaction ──►  verify Apple's signature offline
                                             record purchase (hashed)
                                        ◄──  entitlement token + unlock code
  unlocked                                        DAWN-7K2P-QX91

  Android TV
  ──────────
  enters DAWN-7K2P-QX91 ────────────────►    code valid? under device budget?
                                        ◄──  entitlement token
  unlocked
```

The entitlement is bound to **the purchase, not to a person**. No email, no password, no account —
which is what keeps the store listing's "no account, no sign-up" true, and keeps the App Privacy
label at **Data Not Collected**.

### The shortcut that covers most users

`PairingService` already carries accounts and the sync config between devices. Put the entitlement
token in `PairingPayload` too. Someone setting up a second device already pairs it to bring their
playlists across, and the unlock simply arrives with everything else. The code flow is the fallback
— for a device paired long ago, or someone who only wants the unlock and not the sync.

### Endpoints (on `aurora-sync`)

```
POST /v1/entitlements/claim
  { store: "apple"|"google", product: "...", proof: "<JWS | purchaseToken>" }
  → { token: "<signed entitlement>", code: "DAWN-7K2P-QX91" }

POST /v1/entitlements/redeem
  { code: "DAWN-7K2P-QX91" }
  → { token: "<signed entitlement>" }        409 once the device budget is spent
```

Two tables: purchases (hash of the store transaction id, unique; store; product; created_at) and
codes (code; purchase_id; redemptions). Nothing else — there is nothing else worth storing, and
anything more becomes a privacy disclosure.

### Verification

- **Apple.** StoreKit 2 hands the app a JWS signed by Apple. The server verifies the certificate
  chain against Apple's root offline and reads `originalTransactionId` and the product id out of the
  payload. No API key, no round trip to Apple.
- **Google.** A service account calling `purchases.products.get` with the purchase token.

### The entitlement token

Signed with Ed25519; the **public** half is compiled into the app.

```json
{ "v": 1, "product": "dawnplayer.pro.lifetime", "store": "apple",
  "purchase": "<first 16 hex of sha256(originalTransactionId)>",
  "issued": "2026-09-03T10:00:00Z", "expires": null }
```

## 6. Two rules that matter more than the cryptography

**Fail open.** The app verifies the cached token offline, against the baked-in public key, and never
requires the network to stay unlocked. If the server is down, or the user is on a plane, or the
domain lapses in three years, paid features keep working. An entitlement check that fails closed on
a timeout is how you earn one-star reviews from people who paid.

**Cap, don't police.** Five redemptions per purchase, resettable by mailing support. Someone will
post a code publicly. Chasing that costs more than the leakage, and every anti-piracy measure lands
hardest on the honest user with a new phone.

## 7. Privacy consequences

Native StoreKit and Play Billing keep the nutrition label at **Data Not Collected** — Apple and
Google run the transaction, we receive a signed assertion and store a hash.

**RevenueCat** would remove most of section 5 and give one entitlement source across both stores. It
is also a third-party processor: the App Privacy label changes, `PrivacyInfo.xcprivacy` changes, the
privacy policy grows a section, and the listing can no longer say there is no server of ours in the
path. That is a real trade in both directions — worth deciding deliberately rather than by reaching
for the convenient package.

## 8. What review will insist on

- A visible **Restore Purchases** control. Paywalls get rejected for missing it.
- Privacy policy and terms links **on the paywall screen itself**.
- Review notes explaining **how to reach the paid features**. Sandbox purchases are unreliable in
  review; the cleanest answer is a hidden entitlement granted to the `aurora` demo account, so the
  reviewer signs in to the demo panel and has everything unlocked. Add that to `§4.3` of
  `store-listing.md` when the time comes.
- The Play listing's "In-app purchases" declaration flips to yes. It is a per-release declaration,
  so nothing about shipping 1.0 without it causes a problem later.

Apply to the **Small Business Program** before the first sale: 15% instead of 30% under $1M a year,
and it is not automatic.

## 9. Open decisions

- Price, and whether a subscription joins the lifetime unlock later.
- Whether sync stays free. It is the feature most likely to become a running cost, and the one most
  naturally recurring — which argues for it being the subscription, if there ever is one.
- Whether the Android TV build is the same purchase as Android phone. It should be; same store,
  same entitlement, nothing to do.
