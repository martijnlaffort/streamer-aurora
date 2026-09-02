#!/usr/bin/env node
//
// App Store Connect from the command line, so the listing is a file in the repo
// rather than forty fields somebody retyped into a web form and will have to
// retype again after the first rejection.
//
// Reads tool/asc-listing.json, which mirrors docs/store-listing.md §4.
//
//   node tool/asc.mjs status              what ASC currently holds
//   node tool/asc.mjs push [--dry-run]    write the listing, review notes, age rating
//   node tool/asc.mjs shots <dir>         upload 6.9" screenshots, in order
//
// Auth uses the same App Store Connect API key the release workflow uses.
// Set these, or pass --issuer:
//
//   $env:ASC_ISSUER_ID = "…"                       (Users and Access → Integrations)
//   $env:ASC_KEY_ID    = "77QHZJDRNT"              (defaults to this)
//   $env:ASC_KEY_P8    = "$env:USERPROFILE\dawnplayer-ios\AuthKey_77QHZJDRNT.p8"
//
// Deliberately does NOT submit for review, set pricing, or accept any
// agreement: those carry legal attestations that belong to a person clicking
// them, not to a script.

import { createHash, createSign } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const BASE = 'https://api.appstoreconnect.apple.com';
const HERE = dirname(fileURLToPath(import.meta.url));
const LISTING = JSON.parse(readFileSync(join(HERE, 'asc-listing.json'), 'utf8'));

const argv = process.argv.slice(2);
const command = argv[0] ?? 'status';
const flag = (name) => argv.includes(name);
const value = (name) => {
  const i = argv.indexOf(name);
  return i === -1 ? undefined : argv[i + 1];
};

// ---------------------------------------------------------------- auth

function bearer() {
  const keyId = process.env.ASC_KEY_ID || '77QHZJDRNT';
  const issuerId = process.env.ASC_ISSUER_ID || value('--issuer');
  const keyPath =
    process.env.ASC_KEY_P8 ||
    join(homedir(), 'dawnplayer-ios', `AuthKey_${keyId}.p8`);

  if (!issuerId) {
    die(
      'No issuer id. Set ASC_ISSUER_ID or pass --issuer <uuid>.\n' +
        'App Store Connect → Users and Access → Integrations → App Store Connect API,\n' +
        'the "Issuer ID" printed above the key table.',
    );
  }

  let key;
  try {
    key = readFileSync(keyPath, 'utf8');
  } catch {
    die(`Cannot read the private key at ${keyPath}. Set ASC_KEY_P8 to its path.`);
  }

  const b64 = (o) =>
    Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' });
  // Apple rejects anything longer than 20 minutes.
  const body = b64({ iss: issuerId, iat: now, exp: now + 19 * 60, aud: 'appstoreconnect-v1' });
  const signer = createSign('SHA256');
  signer.update(`${head}.${body}`);
  // ES256 wants the raw r‖s pair; Node signs DER by default, which Apple reads
  // as a malformed token and answers with a bare 401.
  const sig = signer.sign({ key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${head}.${body}.${sig}`;
}

const TOKEN = bearer();

async function api(method, path, body) {
  const res = await fetch(path.startsWith('http') ? path : BASE + path, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    /* Apple occasionally answers with a bare body; keep the text for the error */
  }
  if (!res.ok) {
    const detail =
      json?.errors?.map((e) => `${e.title}${e.detail ? ` — ${e.detail}` : ''}`).join('\n    ') ||
      text ||
      res.statusText;
    throw new Error(`${method} ${path} → ${res.status}\n    ${detail}`);
  }
  return json;
}

function die(message) {
  console.error(message);
  process.exit(1);
}

// ---------------------------------------------------------------- lookups

async function app() {
  const found = await api(
    'GET',
    `/v1/apps?filter[bundleId]=${encodeURIComponent(LISTING.bundleId)}&limit=1`,
  );
  const record = found.data?.[0];
  if (!record) {
    die(
      `No app with bundle id ${LISTING.bundleId} in this account.\n` +
        'Create it first: App Store Connect → Apps → + → New App.',
    );
  }
  return record;
}

/** The editable appInfo — the one holding name, subtitle and the age rating. */
async function editableAppInfo(appId) {
  const infos = await api('GET', `/v1/apps/${appId}/appInfos`);
  const stateOf = (i) => i.attributes?.state ?? i.attributes?.appStoreState ?? '';
  const editable = infos.data.find((i) => !/READY_FOR_DISTRIBUTION|REMOVED/.test(stateOf(i)));
  return editable ?? infos.data[0];
}

/** The version being prepared; created if this is the first one. */
async function editableVersion(appId) {
  const versions = await api(
    'GET',
    `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=20`,
  );
  const editable = versions.data.find(
    (v) => !/READY_FOR_SALE|REPLACED_WITH_NEW_VERSION|REMOVED_FROM_SALE/.test(
      v.attributes?.appStoreState ?? v.attributes?.appVersionState ?? '',
    ),
  );
  if (editable) return editable;

  console.log(`  creating version ${LISTING.versionString}`);
  const created = await api('POST', '/v1/appStoreVersions', {
    data: {
      type: 'appStoreVersions',
      attributes: { platform: 'IOS', versionString: LISTING.versionString },
      relationships: { app: { data: { type: 'apps', id: appId } } },
    },
  });
  return created.data;
}

/** Prefers the app's own primary language over guessing en-US. */
function pickLocale(localizations, primaryLocale) {
  const byLocale = (l) => localizations.find((x) => x.attributes.locale === l);
  return (
    byLocale(primaryLocale) ||
    byLocale('en-US') ||
    byLocale('en-GB') ||
    localizations[0]
  );
}

// ---------------------------------------------------------------- status

async function status() {
  const record = await app();
  const a = record.attributes;
  console.log(`App        ${a.name}  (${a.bundleId})`);
  console.log(`           id ${record.id} · SKU ${a.sku} · primary locale ${a.primaryLocale}`);

  const info = await editableAppInfo(record.id);
  const infoLocs = await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations`);
  const infoLoc = pickLocale(infoLocs.data, a.primaryLocale);
  console.log(`\nApp info   state ${info.attributes?.state ?? info.attributes?.appStoreState}`);
  console.log(`           name        ${infoLoc?.attributes.name || '— empty —'}`);
  console.log(`           subtitle    ${infoLoc?.attributes.subtitle || '— empty —'}`);
  console.log(`           privacy url ${infoLoc?.attributes.privacyPolicyUrl || '— empty —'}`);

  const version = await editableVersion(record.id);
  const vs = version.attributes;
  console.log(
    `\nVersion    ${vs.versionString}  state ${vs.appStoreState ?? vs.appVersionState}`,
  );
  const verLocs = await api(
    'GET',
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  const verLoc = pickLocale(verLocs.data, a.primaryLocale);
  const v = verLoc?.attributes ?? {};
  console.log(`           description  ${v.description ? `${v.description.length} chars` : '— empty —'}`);
  console.log(`           keywords     ${v.keywords || '— empty —'}`);
  console.log(`           promo text   ${v.promotionalText ? 'set' : '— empty —'}`);
  console.log(`           support url  ${v.supportUrl || '— empty —'}`);
  console.log(`           marketing    ${v.marketingUrl || '— empty —'}`);

  const sets = verLoc
    ? await api('GET', `/v1/appStoreVersionLocalizations/${verLoc.id}/appScreenshotSets`)
    : { data: [] };
  if (sets.data.length === 0) {
    console.log('           screenshots  — none —');
  }
  for (const set of sets.data) {
    const shots = await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`);
    console.log(
      `           screenshots  ${set.attributes.screenshotDisplayType}: ${shots.data.length}`,
    );
  }

  let review = null;
  try {
    review = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  } catch {
    /* 404 until it exists */
  }
  const r = review?.data?.attributes;
  console.log(`\nReview     notes        ${r?.notes ? `${r.notes.length} chars` : '— empty —'}`);
  console.log(`           demo account ${r?.demoAccountName || '— empty —'}`);
  console.log(`           contact      ${r?.contactEmail || '— empty —'} ${r?.contactPhone || ''}`);

  try {
    const age = await api('GET', `/v1/appInfos/${info.id}/ageRatingDeclaration`);
    console.log(
      `\nAge rating unrestrictedWebAccess ${age.data.attributes.unrestrictedWebAccess}`,
    );
  } catch {
    console.log('\nAge rating not readable through the API on this app yet');
  }

  const builds = await api(
    'GET',
    `/v1/builds?filter[app]=${record.id}&limit=5&sort=-version`,
  );
  console.log('\nBuilds');
  if (builds.data.length === 0) console.log('           — none —');
  for (const b of builds.data) {
    console.log(
      `           ${b.attributes.version.padEnd(6)} ${b.attributes.processingState}` +
        `  expired=${b.attributes.expired}  uploaded ${b.attributes.uploadedDate}`,
    );
  }
}

// ---------------------------------------------------------------- push

async function push() {
  const dry = flag('--dry-run');
  const say = (what) => console.log(`${dry ? 'would set' : 'set'}  ${what}`);
  const record = await app();
  const primary = record.attributes.primaryLocale;

  // 1. Name, subtitle, privacy policy.
  const info = await editableAppInfo(record.id);
  const infoLocs = await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations`);
  const infoLoc = pickLocale(infoLocs.data, primary);
  if (!infoLoc) die('The app has no app-info localization to write to.');
  if (!dry) {
    await api('PATCH', `/v1/appInfoLocalizations/${infoLoc.id}`, {
      data: {
        type: 'appInfoLocalizations',
        id: infoLoc.id,
        attributes: LISTING.appInfo,
      },
    });
  }
  say(`name, subtitle, privacy policy url  (${infoLoc.attributes.locale})`);

  // 2. The version string itself. A build is only offered for a version whose
  //    string matches its CFBundleShortVersionString exactly — an ASC record
  //    saying "1.0" against binaries saying "1.0.0" shows an empty build picker
  //    and no hint as to why.
  const version = await editableVersion(record.id);
  if (version.attributes.versionString !== LISTING.versionString) {
    if (!dry) {
      await api('PATCH', `/v1/appStoreVersions/${version.id}`, {
        data: {
          type: 'appStoreVersions',
          id: version.id,
          attributes: { versionString: LISTING.versionString },
        },
      });
    }
    say(
      `version string ${version.attributes.versionString} → ${LISTING.versionString}` +
        ' (so the uploaded builds can be attached)',
    );
  }

  // 3. Description, keywords, promo text, URLs.
  const verLocs = await api(
    'GET',
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  let verLoc = pickLocale(verLocs.data, primary);
  if (!verLoc) {
    if (dry) {
      say(`a ${primary} version localization (none exists yet)`);
    } else {
      const created = await api('POST', '/v1/appStoreVersionLocalizations', {
        data: {
          type: 'appStoreVersionLocalizations',
          attributes: { locale: primary, ...LISTING.version },
          relationships: {
            appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
          },
        },
      });
      verLoc = created.data;
      say(`description, keywords, promo text, urls  (${primary}, created)`);
    }
  } else {
    if (!dry) {
      await api('PATCH', `/v1/appStoreVersionLocalizations/${verLoc.id}`, {
        data: {
          type: 'appStoreVersionLocalizations',
          id: verLoc.id,
          attributes: LISTING.version,
        },
      });
    }
    say(`description, keywords, promo text, urls  (${verLoc.attributes.locale})`);
  }

  // 4. Review notes and the demo account. Apple requires a phone number, and a
  //    half-filled review detail is worse than none — it looks answered.
  const detail = { ...LISTING.reviewDetail };
  delete detail._comment;
  if (!detail.contactPhone) {
    console.log(
      'skip  review details — contactPhone is empty in tool/asc-listing.json.\n' +
        '      Apple requires it; fill it in and run push again.',
    );
  } else {
    let existing = null;
    try {
      existing = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
    } catch {
      /* not created yet */
    }
    if (!dry) {
      if (existing?.data) {
        await api('PATCH', `/v1/appStoreReviewDetails/${existing.data.id}`, {
          data: { type: 'appStoreReviewDetails', id: existing.data.id, attributes: detail },
        });
      } else {
        await api('POST', '/v1/appStoreReviewDetails', {
          data: {
            type: 'appStoreReviewDetails',
            attributes: detail,
            relationships: {
              appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
            },
          },
        });
      }
    }
    say('review notes, demo credentials, review contact');
  }

  // 5. Age rating. Apple has reshaped this questionnaire more than once, so a
  //    rejected field is reported rather than fatal — the rest still lands.
  const age = { ...LISTING.ageRating };
  delete age._comment;
  try {
    const current = await api('GET', `/v1/appInfos/${info.id}/ageRatingDeclaration`);
    if (!dry) {
      await api('PATCH', `/v1/ageRatingDeclarations/${current.data.id}`, {
        data: { type: 'ageRatingDeclarations', id: current.data.id, attributes: age },
      });
    }
    say('age rating questionnaire (unrestricted web access = yes)');
  } catch (error) {
    console.log(`skip  age rating — ${error.message.split('\n')[0]}`);
    console.log('      Answer it in the web UI: Unrestricted Web Access = Yes, expect 17+.');
  }

  console.log(
    '\nStill yours to do in the UI: pricing (Free), availability, the App Privacy\n' +
      'nutrition label (Data Not Collected), attaching the build, and Submit.',
  );
}

// ---------------------------------------------------------------- screenshots

// The order they appear in on the product page. Anything else in the directory
// follows, alphabetically.
const SHOT_ORDER = ['home', 'live', 'guide', 'movies', 'series', 'player'];

async function shots(dir) {
  if (!dir) die('Usage: node tool/asc.mjs shots <directory of 1320x2868 pngs>');
  const files = readdirSync(dir)
    .filter((f) => f.toLowerCase().endsWith('.png'))
    .sort((a, b) => {
      const rank = (f) => {
        const i = SHOT_ORDER.indexOf(basename(f, '.png').toLowerCase());
        return i === -1 ? SHOT_ORDER.length : i;
      };
      return rank(a) - rank(b) || a.localeCompare(b);
    });
  if (files.length === 0) die(`No .png files in ${dir}`);

  const record = await app();
  const version = await editableVersion(record.id);
  const verLocs = await api(
    'GET',
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  const verLoc = pickLocale(verLocs.data, record.attributes.primaryLocale);
  if (!verLoc) die('No version localization to attach screenshots to — run push first.');

  const sets = await api(
    'GET',
    `/v1/appStoreVersionLocalizations/${verLoc.id}/appScreenshotSets`,
  );
  // There is no APP_IPHONE_69 in the API. Apple never added a display type for
  // the 6.9" devices — their 1320x2868 screenshots go into the 6.7" set, which
  // is what App Store Connect labels "iPhone 6.9\" Display" in the web UI.
  const DISPLAY_TYPE = 'APP_IPHONE_67';
  let set = sets.data.find((s) => s.attributes.screenshotDisplayType === DISPLAY_TYPE);
  if (!set) {
    const created = await api('POST', '/v1/appScreenshotSets', {
      data: {
        type: 'appScreenshotSets',
        attributes: { screenshotDisplayType: DISPLAY_TYPE },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: 'appStoreVersionLocalizations', id: verLoc.id },
          },
        },
      },
    });
    set = created.data;
    console.log('created the 6.9" screenshot set');
  }

  if (flag('--replace')) {
    const existing = await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`);
    for (const shot of existing.data) {
      await api('DELETE', `/v1/appScreenshots/${shot.id}`);
    }
    if (existing.data.length) console.log(`removed ${existing.data.length} existing screenshots`);
  }

  const uploaded = [];
  for (const file of files) {
    const path = join(dir, file);
    const bytes = readFileSync(path);
    const reserved = await api('POST', '/v1/appScreenshots', {
      data: {
        type: 'appScreenshots',
        attributes: { fileSize: bytes.length, fileName: file },
        relationships: {
          appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } },
        },
      },
    });
    for (const op of reserved.data.attributes.uploadOperations ?? []) {
      const headers = {};
      for (const h of op.requestHeaders ?? []) headers[h.name] = h.value;
      const res = await fetch(op.url, {
        method: op.method,
        headers,
        body: bytes.subarray(op.offset, op.offset + op.length),
      });
      if (!res.ok) die(`Uploading ${file} failed: ${res.status} ${await res.text()}`);
    }
    await api('PATCH', `/v1/appScreenshots/${reserved.data.id}`, {
      data: {
        type: 'appScreenshots',
        id: reserved.data.id,
        attributes: {
          uploaded: true,
          sourceFileChecksum: createHash('md5').update(bytes).digest('hex'),
        },
      },
    });
    uploaded.push(reserved.data.id);
    console.log(`uploaded ${file}`);
  }

  // Apple keeps its own order, which is not upload order.
  await api('PATCH', `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
    data: uploaded.map((id) => ({ type: 'appScreenshots', id })),
  });
  console.log(`ordered ${uploaded.length} screenshots: ${files.join(', ')}`);
}

// ---------------------------------------------------------------- main

try {
  if (command === 'status') await status();
  else if (command === 'push') await push();
  else if (command === 'shots') await shots(argv[1]);
  else die(`Unknown command "${command}". Try status, push, or shots <dir>.`);
} catch (error) {
  die(String(error.message ?? error));
}
