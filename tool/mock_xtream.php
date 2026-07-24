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

$MOVIES = [
    1001 => ['name' => 'Big Buck Bunny (720p clip)',
             'url' => 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4'],
    1002 => ['name' => 'Big Buck Bunny (360p clip)',
             'url' => 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4'],
];

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
            json_out([['category_id' => '2', 'category_name' => 'Test Movies', 'parent_id' => 0]]);

        case 'get_series_categories':
            json_out([['category_id' => '3', 'category_name' => 'Test Series', 'parent_id' => 0]]);

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
                    'stream_id' => $id, 'stream_icon' => '', 'rating' => '7.5',
                    'added' => '1700000000', 'category_id' => '2',
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
                    'plot' => 'A large and lovable rabbit deals with three tiny bullies.',
                    'genre' => 'Animation / Short', 'cast' => 'Big Buck Bunny',
                    'duration_secs' => 10, 'rating' => '7.5',
                    'releasedate' => '2008-05-10', 'movie_image' => '',
                    'backdrop_path' => [],
                ],
                'movie_data' => [
                    'stream_id' => $id, 'name' => $m['name'], 'added' => '1700000000',
                    'category_id' => '2', 'container_extension' => 'mp4',
                ],
            ]);

        case 'get_series':
            json_out([[
                'num' => 1, 'name' => 'Buck Tales', 'series_id' => 15,
                'cover' => '', 'plot' => 'Adventures of a big rabbit.',
                'cast' => 'Big Buck Bunny', 'genre' => 'Animation',
                'releaseDate' => '2008-05-10', 'rating' => '8', 'category_id' => '3',
            ]]);

        case 'get_series_info':
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
                    'episode_count' => count($eps), 'cover' => '',
                ]],
                'info' => [
                    'name' => 'Buck Tales', 'cover' => '',
                    'plot' => 'Adventures of a big rabbit.', 'genre' => 'Animation',
                    'cast' => 'Big Buck Bunny', 'releaseDate' => '2008-05-10',
                    'rating' => '8', 'category_id' => '3',
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
    header('Location: ' . $target, true, 302);
    exit;
}

http_response_code(404);
echo 'mock_xtream: unknown path';
