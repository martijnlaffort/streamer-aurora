<?php
/**
 * Mock Xtream Codes panel for local testing.
 *
 * Run:    php -S 127.0.0.1:8082 tool/mock_xtream.php
 * Probe:  server http://127.0.0.1:8082 (Windows desktop)
 *         server http://10.0.2.2:8082  (Android emulator; 10.0.2.2 = host loopback)
 *         username: aurora   password: test
 *
 * Speaks enough of player_api.php for Aurora: auth, categories, live/VOD/series
 * lists, VOD/series info, short EPG. Stream URLs (/live, /movie, /series)
 * redirect to legal, publicly available streams: Apple's multi-audio/subtitle
 * HLS sample, DW English and Red Bull TV (free-to-air live), and
 * test-videos.co.uk Big Buck Bunny clips. No real provider needed.
 */

const MOCK_USER = 'aurora';
const MOCK_PASS = 'test';

$LIVE = [
    1 => ['name' => 'Apple Test Pattern (multi audio/subs)', 'epg' => 'apple.test',
          'url' => 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8'],
    2 => ['name' => 'DW English', 'epg' => 'dw.en',
          'url' => 'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8'],
    3 => ['name' => 'Red Bull TV', 'epg' => 'redbull.tv',
          'url' => 'https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8'],
];

// A generated catalog large enough to make Home rails and grids feel real.
// Posters/backdrops come from picsum.photos (stable per seed); every stream
// URL still resolves to a playable Big Buck Bunny clip.
$VOD_CATEGORIES = [20 => 'Action', 21 => 'Drama', 22 => 'Sci-Fi', 23 => 'Documentary'];

$MOVIE_CLIP_URLS = [
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4',
];

$MOVIES = [];
$adjectives = ['Silent', 'Crimson', 'Endless', 'Broken', 'Golden', 'Hidden',
               'Electric', 'Frozen', 'Burning', 'Midnight', 'Distant', 'Savage'];
$nouns = ['Harbor', 'Empire', 'Signal', 'Garden', 'Protocol', 'Horizon',
          'Echo', 'Kingdom', 'Circuit', 'Meridian', 'Voyage', 'Frontier'];
for ($i = 0; $i < 48; $i++) {
    $id = 1001 + $i;
    // Shift the noun sequence per 12-block so all 48 names are distinct.
    $MOVIES[$id] = [
        'name'   => $adjectives[$i % 12] . ' ' . $nouns[($i * 7 + intdiv($i, 12) + 3) % 12],
        'cat'    => (string) (20 + $i % 4),
        'year'   => 1996 + ($i * 13) % 30,
        'rating' => number_format(5.0 + ($i * 37 % 45) / 10, 1, '.', ''),
        'added'  => time() - $i * 86400 * 3,
        'url'    => $MOVIE_CLIP_URLS[$i % 2],
    ];
}

$SERIES = [];
for ($i = 0; $i < 6; $i++) {
    $id = 15 + $i;
    $SERIES[$id] = [
        'name'   => $adjectives[($i * 5 + 2) % 12] . ' ' . $nouns[($i * 3 + 1) % 12] . 's',
        'year'   => 2010 + $i * 2,
        'rating' => number_format(6.5 + $i * 0.4, 1, '.', ''),
    ];
}

$EPISODES = [
    5001 => ['title' => 'S01E01 - First Hop', 'season' => 1, 'num' => 1,
             'url' => 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4'],
    5002 => ['title' => 'S01E02 - The Meadow', 'season' => 1, 'num' => 2,
             'url' => 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4'],
];

function json_out($data): void
{
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function creds_ok(string $user, string $pass): bool
{
    return $user === MOCK_USER && $pass === MOCK_PASS;
}

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// --- player_api.php ----------------------------------------------------------
if ($path === '/player_api.php') {
    $user = $_GET['username'] ?? '';
    $pass = $_GET['password'] ?? '';
    if (!creds_ok($user, $pass)) {
        json_out(['user_info' => ['auth' => 0]]);
    }

    $action = $_GET['action'] ?? '';
    switch ($action) {
        case '':
            json_out([
                'user_info' => [
                    'username' => MOCK_USER, 'auth' => 1, 'status' => 'Active',
                    'exp_date' => (string) (time() + 30 * 86400),
                    'max_connections' => '2', 'active_cons' => '0',
                    'allowed_output_formats' => ['m3u8', 'ts'],
                ],
                'server_info' => [
                    'url' => $_SERVER['HTTP_HOST'] ?? '127.0.0.1:8082',
                    'server_protocol' => 'http', 'timezone' => 'UTC',
                    'timestamp_now' => time(),
                ],
            ]);

        case 'get_live_categories':
            json_out([['category_id' => '1', 'category_name' => 'Test Live', 'parent_id' => 0]]);

        case 'get_vod_categories':
            $rows = [];
            foreach ($GLOBALS['VOD_CATEGORIES'] as $id => $name) {
                $rows[] = ['category_id' => (string) $id, 'category_name' => $name, 'parent_id' => 0];
            }
            json_out($rows);

        case 'get_series_categories':
            json_out([['category_id' => '30', 'category_name' => 'Shows', 'parent_id' => 0]]);

        case 'get_live_streams':
            $rows = [];
            $num = 1;
            foreach ($GLOBALS['LIVE'] as $id => $ch) {
                $rows[] = [
                    'num' => $num++, 'name' => $ch['name'], 'stream_type' => 'live',
                    'stream_id' => $id, 'stream_icon' => '',
                    'epg_channel_id' => $ch['epg'], 'added' => '1700000000',
                    'category_id' => '1', 'tv_archive' => 0,
                ];
            }
            json_out($rows);

        case 'get_vod_streams':
            $rows = [];
            $num = 1;
            foreach ($GLOBALS['MOVIES'] as $id => $m) {
                $rows[] = [
                    'num' => $num++, 'name' => $m['name'], 'stream_type' => 'movie',
                    'stream_id' => $id,
                    'stream_icon' => "https://picsum.photos/seed/aurora$id/300/450",
                    'rating' => $m['rating'], 'year' => (string) $m['year'],
                    'added' => (string) $m['added'], 'category_id' => $m['cat'],
                    'container_extension' => 'mp4',
                ];
            }
            json_out($rows);

        case 'get_vod_info':
            $id = (int) ($_GET['vod_id'] ?? 0);
            $m = $GLOBALS['MOVIES'][$id] ?? null;
            if ($m === null) {
                json_out(['info' => [], 'movie_data' => []]);
            }
            json_out([
                'info' => [
                    'name' => $m['name'],
                    'plot' => "An evocative tale of {$m['name']}: ten seconds of a "
                            . 'large and lovable rabbit standing in for real cinema.',
                    'genre' => $GLOBALS['VOD_CATEGORIES'][(int) $m['cat']] ?? 'Drama',
                    'cast' => 'Big Buck Bunny, Frank, Rinky, Gamera',
                    'duration_secs' => 600, 'rating' => $m['rating'],
                    'releasedate' => $m['year'] . '-05-10',
                    'movie_image' => "https://picsum.photos/seed/aurora$id/300/450",
                    'backdrop_path' => ["https://picsum.photos/seed/aurorabd$id/1280/720"],
                ],
                'movie_data' => [
                    'stream_id' => $id, 'name' => $m['name'],
                    'added' => (string) $m['added'],
                    'category_id' => $m['cat'], 'container_extension' => 'mp4',
                ],
            ]);

        case 'get_series':
            $rows = [];
            $num = 1;
            foreach ($GLOBALS['SERIES'] as $id => $s) {
                $rows[] = [
                    'num' => $num++, 'name' => $s['name'], 'series_id' => $id,
                    'cover' => "https://picsum.photos/seed/auroras$id/300/450",
                    'plot' => "The continuing story of {$s['name']}.",
                    'cast' => 'Big Buck Bunny', 'genre' => 'Drama',
                    'releaseDate' => $s['year'] . '-01-01',
                    'rating' => $s['rating'], 'category_id' => '30',
                ];
            }
            json_out($rows);

        case 'get_series_info':
            $sid = (int) ($_GET['series_id'] ?? 15);
            $s = $GLOBALS['SERIES'][$sid] ?? ['name' => 'Unknown Show', 'year' => 2020, 'rating' => '7.0'];
            $eps = [];
            foreach ($GLOBALS['EPISODES'] as $id => $e) {
                $eps[] = [
                    'id' => (string) $id, 'episode_num' => $e['num'],
                    'title' => $e['title'], 'container_extension' => 'mp4',
                    'info' => ['plot' => 'Rabbit things happen.', 'duration_secs' => 10],
                    'added' => '1700000000', 'season' => $e['season'],
                ];
            }
            json_out([
                'seasons' => [[
                    'id' => 100, 'name' => 'Season 1', 'season_number' => 1,
                    'episode_count' => count($eps),
                    'cover' => "https://picsum.photos/seed/auroras$sid/300/450",
                ]],
                'info' => [
                    'name' => $s['name'],
                    'cover' => "https://picsum.photos/seed/auroras$sid/300/450",
                    'plot' => "The continuing story of {$s['name']}.",
                    'genre' => 'Drama', 'cast' => 'Big Buck Bunny',
                    'releaseDate' => $s['year'] . '-01-01',
                    'rating' => $s['rating'], 'category_id' => '30',
                ],
                'episodes' => ['1' => $eps],
            ]);

        case 'get_short_epg':
            $id = (int) ($_GET['stream_id'] ?? 0);
            $name = $GLOBALS['LIVE'][$id]['name'] ?? 'Unknown';
            $limit = max(1, (int) ($_GET['limit'] ?? 4));
            $rows = [];
            $start = time() - 900; // current programme started 15 min ago
            for ($i = 0; $i < $limit; $i++) {
                $stop = $start + 3600;
                $rows[] = [
                    'id' => (string) (9000 + $i), 'epg_id' => (string) $id,
                    'title' => base64_encode($i === 0 ? "Now on $name" : "Later on $name #$i"),
                    'description' => base64_encode('Mock programme for testing.'),
                    'channel_id' => $GLOBALS['LIVE'][$id]['epg'] ?? '',
                    'start_timestamp' => (string) $start,
                    'stop_timestamp' => (string) $stop,
                ];
                $start = $stop;
            }
            json_out(['epg_listings' => $rows]);

        default:
            json_out([]);
    }
}

// --- M3U playlist (for testing the M3uSource path) ---------------------------
if ($path === '/playlist.m3u') {
    header('Content-Type: application/x-mpegurl');
    $host = $_SERVER['HTTP_HOST'] ?? '127.0.0.1:8082';
    echo "#EXTM3U\n";
    foreach ($LIVE as $id => $ch) {
        echo "#EXTINF:-1 tvg-id=\"{$ch['epg']}\" group-title=\"Test Live\",{$ch['name']}\n";
        echo "http://$host/live/aurora/test/$id.ts\n";
    }
    exit;
}

// --- Stream endpoints: redirect to the real public stream --------------------
if (preg_match('#^/(live|movie|series)/([^/]+)/([^/]+)/(\d+)\.\w+$#', $path, $m)) {
    [, $kind, $user, $pass, $id] = $m;
    if (!creds_ok(urldecode($user), urldecode($pass))) {
        http_response_code(403);
        exit;
    }
    $table = match ($kind) {
        'live' => $GLOBALS['LIVE'],
        'movie' => $GLOBALS['MOVIES'],
        'series' => $GLOBALS['EPISODES'],
    };
    $target = $table[(int) $id]['url'] ?? null;
    if ($target === null) {
        http_response_code(404);
        exit;
    }
    // HLS master playlists break under a plain 302: players resolve relative
    // variant/media URIs against the pre-redirect URL (the mock), not the CDN.
    // Proxy the playlist and rewrite relative URLs to absolute instead.
    if (str_contains($target, '.m3u8')) {
        serve_hls($target);
    }
    // Direct media (MP4, TS) has no sub-resources — a redirect is fine.
    header('Location: ' . $target, true, 302);
    exit;
}

/**
 * Fetch an HLS playlist and absolutize its relative URLs (both bare lines and
 * URI="..." attributes on EXT-X-MEDIA/KEY tags) so a client reaching it via
 * the mock resolves variants/renditions/segments against the real CDN.
 */
function serve_hls(string $url): void
{
    $ctx = stream_context_create(['http' => [
        'follow_location' => 1,
        'header' => "User-Agent: Aurora-mock/1.0\r\n",
        'timeout' => 15,
    ]]);
    $body = @file_get_contents($url, false, $ctx);
    if ($body === false) {
        http_response_code(502);
        echo 'mock_xtream: could not fetch upstream HLS';
        exit;
    }
    $base = substr($url, 0, strrpos($url, '/') + 1);
    $abs = static function (string $u) use ($base): string {
        return preg_match('#^https?://#', $u) ? $u : $base . $u;
    };
    $out = [];
    foreach (preg_split('/\r?\n/', $body) as $line) {
        $t = trim($line);
        if ($t === '') {
            $out[] = $line;
        } elseif ($t[0] === '#') {
            $out[] = preg_replace_callback(
                '/URI="([^"]+)"/',
                static fn ($mm) => 'URI="' . $abs($mm[1]) . '"',
                $line
            );
        } else {
            $out[] = $abs($t);
        }
    }
    header('Content-Type: application/vnd.apple.mpegurl');
    echo implode("\n", $out);
    exit;
}

http_response_code(404);
echo 'mock_xtream: unknown path';
