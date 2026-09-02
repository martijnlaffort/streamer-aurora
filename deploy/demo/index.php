<?php
/**
 * Web root for demo.dawnplayer.com — the panel App Review and Play review
 * sign in to.
 *
 * It is deliberately the same file the app is developed against
 * (tool/mock_xtream.php): one panel, one behaviour, no second thing to keep
 * in step. This file only pins the catalogue size and takes away the query
 * overrides that are fine on a laptop and not fine on a public host.
 *
 * Credentials are in tool/mock_xtream.php: aurora / test.
 */

// Big enough to look like a real line in a screenshot, small enough that a
// reviewer's first load finishes in about a second. Live channels above the
// first three reuse those three real streams round-robin, so every channel in
// the list actually plays.
putenv('MOCK_LCOUNT=60');
putenv('MOCK_COUNT=200');
putenv('MOCK_SCOUNT=24');

// The panel lets ?count=/?scount=/?lcount= override the catalogue size, which
// is how the 40k-item performance runs are done locally. On a public URL that
// is a free denial-of-service, so the overrides do not exist here.
unset($_GET['count'], $_GET['scount'], $_GET['lcount']);

// Belt and braces. MOCK_CANON fills the catalogue with real award-winning
// titles so the discovery rails have something to resolve against, which is
// useful on a laptop and indefensible here: a demo library advertising
// Oppenheimer and Breaking Bad to App Review *is* the guideline 5.2.3 problem.
// It defaults to off; this makes sure a stray server env cannot turn it on.
putenv('MOCK_CANON=0');

// The panel answers "404 unknown path" at the bare domain, and this domain is
// printed in the App Review notes — so the one URL a reviewer is most likely to
// paste into a browser is the one that looks broken. Say what this host is
// instead. Everything below /player_api.php etc. still goes to the panel.
if (($_SERVER['REQUEST_URI'] ?? '/') === '/') {
    header('Content-Type: text/html; charset=utf-8');
    header('X-Robots-Tag: noindex');
    echo <<<HTML
    <!doctype html>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Dawn Player demo panel</title>
    <style>
      body { background:#0B0D12; color:#E6E8EE; font:16px/1.6 -apple-system,BlinkMacSystemFont,
             "Segoe UI",Roboto,sans-serif; margin:0; padding:3rem 1.5rem; }
      main { max-width:34rem; margin:0 auto; }
      h1 { font-size:1.4rem; margin:0 0 1rem; }
      code { background:#171A22; padding:.15rem .4rem; border-radius:.25rem; }
      dl { background:#171A22; padding:1rem 1.25rem; border-radius:.5rem; }
      dt { color:#8A90A2; font-size:.85rem; }
      dd { margin:0 0 .75rem; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
      dd:last-child { margin-bottom:0; }
      p { color:#B6BBC9; }
      a { color:#8B7CFF; }
    </style>
    <main>
      <h1>Dawn Player — test panel</h1>
      <p>This host exists so App Store and Play reviewers can sign in to
      <strong>Dawn Player</strong> without anyone handing them a real IPTV subscription. It is not a
      content service and it is not for public use.</p>
      <dl>
        <dt>Server</dt><dd>https://demo.dawnplayer.com</dd>
        <dt>Username</dt><dd>aurora</dd>
        <dt>Password</dt><dd>test</dd>
      </dl>
      <p>Everything it serves is legal and publicly available: Apple's sample HLS stream, DW English
      and Red Bull TV (both free-to-air), and the Blender Foundation's <em>Big Buck Bunny</em> and
      <em>Sintel</em> (both Creative Commons Attribution). The catalogue around them is generated
      placeholder data.</p>
      <p><a href="https://dawnplayer.com">dawnplayer.com</a></p>
    </main>
    HTML;
    exit;
}

// Deployed from the repo (Ploi git deploy, web directory /deploy/demo) the
// panel is two levels up. Uploaded by hand, it sits next to this file.
$panel = dirname(__DIR__, 2) . '/tool/mock_xtream.php';
if (!is_file($panel)) {
    $panel = __DIR__ . '/mock_xtream.php';
}
if (!is_file($panel)) {
    http_response_code(500);
    header('Content-Type: text/plain');
    exit("mock_xtream.php not found — see deploy/demo/README.md\n");
}

require $panel;
