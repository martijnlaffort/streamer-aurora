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
