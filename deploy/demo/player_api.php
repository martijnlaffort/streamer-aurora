<?php
/**
 * nginx hands any URI ending in .php straight to PHP-FPM, so try_files never
 * gets the chance to route /player_api.php to index.php — without this file
 * FPM answers "Primary script unknown" and the app sees a 404 on the one
 * endpoint that matters. The panel dispatches on REQUEST_URI, so simply
 * loading it here is enough.
 */
require __DIR__ . '/index.php';
