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
 * HLS sample, DW English and Red Bull TV (free-to-air live), and the Blender
 * Foundation's Big Buck Bunny and Sintel (both CC-BY, served by W3C's public
 * media host). No real provider needed.
 */

const MOCK_USER = 'aurora';
const MOCK_PASS = 'test';

// Real, publicly available streams. The first few generated live channels map to
// these so live playback still works at any catalog size; every other generated
// channel reuses one of them round-robin.
$REAL_LIVE = [
    ['name' => 'Apple Test Pattern (multi audio/subs)', 'epg' => 'apple.test',
     'url' => 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8'],
    ['name' => 'DW English', 'epg' => 'dw.en',
     'url' => 'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8'],
    ['name' => 'Red Bull TV', 'epg' => 'redbull.tv',
     'url' => 'https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8'],
];

// Films. Both are Creative Commons Attribution, both from the Blender
// Foundation, both served by W3C's public media host with range requests, so
// seeking works.
//
// Length matters here. These used to be ten-second clips, which made the demo
// panel look broken to anyone actually using it — a "film" that ends before you
// have finished reading its title — and made the store screenshot of the player
// land on 0:09 of 0:10 with a play button over a stopped film. First in the list
// is the ten-minute one, because it is the film a reviewer opens first.
$MOVIE_CLIP_URLS = [
    'https://media.w3.org/2010/05/bunny/movie.mp4',        // Big Buck Bunny, ~10 min
    'https://media.w3.org/2010/05/sintel/trailer.mp4',     // Sintel trailer, 52s
];

// Category names. Ids: live 1..N, VOD 20..39, series 300..307 (types are stored
// separately, so the ranges only need to be unique per type).
$LIVE_CAT_NAMES = ['Sports', 'News', 'Entertainment', 'Movies', 'Kids', 'Music',
                   'Documentary', 'International', 'Local', 'Premium'];
$VOD_CAT_NAMES = ['Action', 'Drama', 'Sci-Fi', 'Documentary', 'Comedy', 'Thriller',
                  'Horror', 'Romance', 'Animation', 'Crime', 'Fantasy', 'Adventure',
                  'Mystery', 'Family', 'War', 'Western', 'Music', 'History', 'Sport',
                  'Biography'];
$SERIES_CAT_NAMES = ['Shows', 'Drama Series', 'Comedy Series', 'Crime Series',
                     'Sci-Fi Series', 'Kids Series', 'Docuseries', 'Reality'];

$LIVE_CATEGORIES = [];
foreach ($LIVE_CAT_NAMES as $k => $n) { $LIVE_CATEGORIES[1 + $k] = $n; }
$VOD_CATEGORIES = [];
foreach ($VOD_CAT_NAMES as $k => $n) { $VOD_CATEGORIES[20 + $k] = $n; }
$SERIES_CATEGORIES = [];
foreach ($SERIES_CAT_NAMES as $k => $n) { $SERIES_CATEGORIES[300 + $k] = $n; }

$adjectives = ['Silent', 'Crimson', 'Endless', 'Broken', 'Golden', 'Hidden',
               'Electric', 'Frozen', 'Burning', 'Midnight', 'Distant', 'Savage'];
$nouns = ['Harbor', 'Empire', 'Signal', 'Garden', 'Protocol', 'Horizon',
          'Echo', 'Kingdom', 'Circuit', 'Meridian', 'Voyage', 'Frontier'];

// Catalog sizes. Small by default so dev is fast; set these in the server env
// (or pass ?count=/?scount=/?lcount= per request) to mimic a large real line and
// reproduce on-device behaviour locally, e.g. a big provider:
//   MOCK_LCOUNT=25000 MOCK_COUNT=150000 MOCK_SCOUNT=36000
$MOVIE_COUNT  = (int) ($_GET['count']  ?? (getenv('MOCK_COUNT')  ?: 200));
$SERIES_COUNT = (int) ($_GET['scount'] ?? (getenv('MOCK_SCOUNT') ?: 24));
$LIVE_COUNT   = (int) ($_GET['lcount'] ?? (getenv('MOCK_LCOUNT') ?: 3));

// Rows are GENERATED ON DEMAND from their index rather than materialised into
// big arrays up front: at 150k movies, building the whole catalog on every
// request costs seconds of CPU and hundreds of MB in the mock itself, which
// would swamp the very app-side timings this tool exists to measure. Each
// row is a pure function of its index, so a single item (get_vod_info, a stream
// URL) is computed directly and a per-category listing iterates with a stride.

/** Live channel by index (0-based). Ids are 1-based: id = index + 1. */
function mock_channel(int $i): array
{
    $real = $GLOBALS['REAL_LIVE'][$i % count($GLOBALS['REAL_LIVE'])];
    $catCount = count($GLOBALS['LIVE_CATEGORIES']);
    // The first channels keep their real names so the Live tab is recognisable.
    $isReal = $i < count($GLOBALS['REAL_LIVE']);
    return [
        'id'   => $i + 1,
        'name' => $isReal ? $real['name']
                          : $GLOBALS['LIVE_CAT_NAMES'][$i % $catCount] . ' HD ' . ($i + 1),
        'epg'  => $isReal ? $real['epg'] : 'ch.' . ($i + 1),
        'cat'  => (string) (1 + $i % $catCount),
        'url'  => $real['url'],
    ];
}

/**
 * Real award-winning titles, formatted the messy way a real panel does, so the
 * discovery rails (which match against TMDB lists and the bundled award canon)
 * have something to resolve against. The generated `Silent Harbor 12` names
 * match nothing by design, which would make an empty rail look like a bug.
 * These occupy the first indices; everything after is generated as before.
 */
const CANON_SAMPLE = [
    ['Oppenheimer 2023 4K', 2023],
    ['EN - Parasite (2019)', 2019],
    ['The Godfather 1972 1080p', 1972],
    ['Casablanca', 1943],
    ['NL| Forrest Gump 1994 MULTi', 1994],
    ['Gladiator 2000 WEB-DL', 2000],
    ['Titanic 1997', 1997],
    ['Schindlers List 1993', 1993],
    ['Everything Everywhere All at Once 2022', 2022],
    ['Anora 2024', 2024],
    ['Nomadland 2020', 2020],
    ['Moonlight 2016 x265', 2016],
    ['Argo 2012', 2012],
    ['Amadeus 1984', 1984],
    ['Rocky 1976', 1976],
    ['Platoon 1986', 1986],
    ['Braveheart 1995 HDR', 1995],
    ['The Departed 2006', 2006],
    ['Spotlight 2015', 2015],
    ['One Flew Over the Cuckoos Nest 1975', 1975],
];

/** Movie by index (0-based). Ids start at 1001. */
function mock_movie(int $i): array
{
    $catCount = count($GLOBALS['VOD_CATEGORIES']);
    if ($i < count(CANON_SAMPLE)) {
        [$realName, $realYear] = CANON_SAMPLE[$i];
        return [
            'id'     => 1001 + $i,
            'name'   => $realName,
            'cat'    => (string) (20 + $i % $catCount),
            'year'   => $realYear,
            'rating' => number_format(7.5 + ($i % 25) / 10, 1, '.', ''),
            'added'  => time() - $i * 3600,
            'url'    => $GLOBALS['MOVIE_CLIP_URLS'][$i % 2],
        ];
    }
    return [
        'id'     => 1001 + $i,
        'name'   => $GLOBALS['adjectives'][$i % 12] . ' '
                    . $GLOBALS['nouns'][($i * 7 + intdiv($i, 12)) % 12] . ' ' . ($i + 1),
        'cat'    => (string) (20 + $i % $catCount),
        'year'   => 1980 + ($i * 13) % 45,
        'rating' => number_format(3.0 + ($i * 37 % 70) / 10, 1, '.', ''),
        'added'  => time() - $i * 3600,
        'url'    => $GLOBALS['MOVIE_CLIP_URLS'][$i % 2],
    ];
}

/** Emmy-winning series, likewise so the series award rail has real matches. */
const CANON_SAMPLE_SERIES = [
    ['Breaking Bad', 2008], ['Game of Thrones', 2011], ['The Sopranos', 1999],
    ['Succession', 2018], ['Mad Men', 2007], ['Friends', 1994],
    ['Seinfeld', 1989], ['Ted Lasso', 2020], ['The Bear', 2022],
    ['Fleabag', 2016], ['The Crown', 2016], ['Shogun', 2024],
];

/** Series by index (0-based). Ids start at 15. */
function mock_series(int $i): array
{
    $catCount = count($GLOBALS['SERIES_CATEGORIES']);
    if ($i < count(CANON_SAMPLE_SERIES)) {
        [$realName, $realYear] = CANON_SAMPLE_SERIES[$i];
        return [
            'id'     => 15 + $i,
            'name'   => $realName,
            'cat'    => (string) (300 + $i % $catCount),
            'year'   => $realYear,
            'rating' => number_format(8.0 + ($i % 20) / 10, 1, '.', ''),
        ];
    }
    return [
        'id'     => 15 + $i,
        'name'   => $GLOBALS['adjectives'][($i * 5 + 2) % 12] . ' '
                    . $GLOBALS['nouns'][($i * 3 + 1) % 12] . 's ' . ($i + 1),
        'cat'    => (string) (300 + $i % $catCount),
        'year'   => 1990 + $i % 35,
        'rating' => number_format(3.0 + ($i * 41 % 70) / 10, 1, '.', ''),
    ];
}

/**
 * Indexes of the items in [0,$count) whose category is $want, or all of them
 * when $want is null. Round-robin assignment means one category is exactly
 * every $catCount-th index, so this never walks the whole catalog.
 */
function mock_indexes(?string $want, int $count, int $firstCatId, int $catCount): iterable
{
    if ($want === null) {
        for ($i = 0; $i < $count; $i++) { yield $i; }
        return;
    }
    $offset = (int) $want - $firstCatId;
    if ($offset < 0 || $offset >= $catCount) { return; }
    for ($i = $offset; $i < $count; $i += $catCount) { yield $i; }
}

// Episodes get the shorter of the two, so autoplay-next is reachable without
// sitting through ten minutes.
$EPISODES = [
    5001 => ['title' => 'S01E01 - First Hop', 'season' => 1, 'num' => 1,
             'url' => 'https://media.w3.org/2010/05/sintel/trailer.mp4'],
    5002 => ['title' => 'S01E02 - The Meadow', 'season' => 1, 'num' => 2,
             'url' => 'https://media.w3.org/2010/05/sintel/trailer.mp4'],
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
                    // Behind Ploi's TLS the panel is https, and a client that
                    // believed a hardcoded 'http' would build stream URLs the
                    // reviewer's device refuses. X-Forwarded-Proto first, since
                    // nginx terminates TLS in front of PHP-FPM.
                    'server_protocol' => $_SERVER['HTTP_X_FORWARDED_PROTO']
                        ?? (empty($_SERVER['HTTPS']) || $_SERVER['HTTPS'] === 'off' ? 'http' : 'https'),
                    'timezone' => 'UTC',
                    'timestamp_now' => time(),
                ],
            ]);

        case 'get_live_categories':
            $rows = [];
            foreach ($GLOBALS['LIVE_CATEGORIES'] as $id => $name) {
                $rows[] = ['category_id' => (string) $id, 'category_name' => $name, 'parent_id' => 0];
            }
            json_out($rows);

        case 'get_vod_categories':
            $rows = [];
            foreach ($GLOBALS['VOD_CATEGORIES'] as $id => $name) {
                $rows[] = ['category_id' => (string) $id, 'category_name' => $name, 'parent_id' => 0];
            }
            json_out($rows);

        case 'get_series_categories':
            $rows = [];
            foreach ($GLOBALS['SERIES_CATEGORIES'] as $id => $name) {
                $rows[] = ['category_id' => (string) $id, 'category_name' => $name, 'parent_id' => 0];
            }
            json_out($rows);

        case 'get_live_streams':
            // Honors category_id like a real panel — Aurora refreshes per
            // category to keep memory flat on big catalogs.
            $want = $_GET['category_id'] ?? null;
            $rows = [];
            $num = 1;
            foreach (mock_indexes($want, $LIVE_COUNT, 1, count($LIVE_CATEGORIES)) as $i) {
                $ch = mock_channel($i);
                $rows[] = [
                    'num' => $num++, 'name' => $ch['name'], 'stream_type' => 'live',
                    'stream_id' => $ch['id'], 'stream_icon' => '',
                    'epg_channel_id' => $ch['epg'], 'added' => '1700000000',
                    'category_id' => $ch['cat'], 'tv_archive' => 0,
                ];
            }
            json_out($rows);

        case 'get_vod_streams':
            $want = $_GET['category_id'] ?? null;
            $rows = [];
            $num = 1;
            foreach (mock_indexes($want, $MOVIE_COUNT, 20, count($VOD_CATEGORIES)) as $i) {
                $m = mock_movie($i);
                $id = $m['id'];
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
            $index = $id - 1001;
            if ($index < 0 || $index >= $MOVIE_COUNT) {
                json_out(['info' => [], 'movie_data' => []]);
            }
            $m = mock_movie($index);
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
            $want = $_GET['category_id'] ?? null;
            $rows = [];
            $num = 1;
            foreach (mock_indexes($want, $SERIES_COUNT, 300, count($SERIES_CATEGORIES)) as $i) {
                $s = mock_series($i);
                $id = $s['id'];
                $rows[] = [
                    'num' => $num++, 'name' => $s['name'], 'series_id' => $id,
                    'cover' => "https://picsum.photos/seed/auroras$id/300/450",
                    'plot' => "The continuing story of {$s['name']}.",
                    'cast' => 'Big Buck Bunny', 'genre' => 'Drama',
                    'releaseDate' => $s['year'] . '-01-01',
                    'rating' => $s['rating'], 'category_id' => $s['cat'],
                ];
            }
            json_out($rows);

        case 'get_series_info':
            $sid = (int) ($_GET['series_id'] ?? 15);
            $sindex = $sid - 15;
            $s = ($sindex >= 0 && $sindex < $SERIES_COUNT)
                ? mock_series($sindex)
                : ['name' => 'Unknown Show', 'year' => 2020, 'rating' => '7.0', 'cat' => '300'];
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
                    'rating' => $s['rating'], 'category_id' => $s['cat'],
                ],
                'episodes' => ['1' => $eps],
            ]);

        case 'get_short_epg':
            $id = (int) ($_GET['stream_id'] ?? 0);
            $ch = ($id >= 1 && $id <= $LIVE_COUNT) ? mock_channel($id - 1) : null;
            $name = $ch['name'] ?? 'Unknown';
            $limit = max(1, (int) ($_GET['limit'] ?? 4));
            $rows = [];
            $start = time() - 900; // current programme started 15 min ago
            for ($i = 0; $i < $limit; $i++) {
                $stop = $start + 3600;
                $rows[] = [
                    'id' => (string) (9000 + $i), 'epg_id' => (string) $id,
                    'title' => base64_encode($i === 0 ? "Now on $name" : "Later on $name #$i"),
                    'description' => base64_encode('Mock programme for testing.'),
                    'channel_id' => $ch['epg'] ?? '',
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
    echo "#EXTM3U url-tvg=\"http://$host/xmltv.php\"\n";
    for ($i = 0; $i < $LIVE_COUNT; $i++) {
        $ch = mock_channel($i);
        $group = $LIVE_CATEGORIES[(int) $ch['cat']] ?? 'Test Live';
        echo "#EXTINF:-1 tvg-id=\"{$ch['epg']}\" group-title=\"$group\",{$ch['name']}\n";
        echo "http://$host/live/aurora/test/{$ch['id']}.ts\n";
    }
    exit;
}

// --- XMLTV EPG (Xtream xmltv.php + the M3U url-tvg above) ---------------------
if ($path === '/xmltv.php') {
    header('Content-Type: application/xml');
    // Streamed, not buffered: a real guide for tens of thousands of channels is
    // hundreds of MB, which is the case Aurora's streaming ingest exists for.
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<tv>\n";
    for ($i = 0; $i < $LIVE_COUNT; $i++) {
        $ch = mock_channel($i);
        $eid = htmlspecialchars($ch['epg']);
        echo "  <channel id=\"$eid\"><display-name>"
            . htmlspecialchars($ch['name']) . "</display-name></channel>\n";
    }
    // A programme every hour from 2h ago to 6h ahead, in UTC.
    $slot = (int) floor(time() / 3600) * 3600 - 2 * 3600;
    for ($c = 0; $c < $LIVE_COUNT; $c++) {
        $ch = mock_channel($c);
        $eid = htmlspecialchars($ch['epg']);
        for ($i = 0; $i < 8; $i++) {
            $start = $slot + $i * 3600;
            $stop = $start + 3600;
            $s = gmdate('YmdHis', $start) . ' +0000';
            $e = gmdate('YmdHis', $stop) . ' +0000';
            $hh = gmdate('H:i', $start);
            $title = htmlspecialchars($ch['name'] . " — $hh show");
            echo "  <programme start=\"$s\" stop=\"$e\" channel=\"$eid\">"
                . "<title>$title</title>"
                . "<desc>Mock programme for testing the EPG guide.</desc>"
                . "</programme>\n";
        }
    }
    echo "</tv>\n";
    exit;
}

// --- Stream endpoints: redirect to the real public stream --------------------
if (preg_match('#^/(live|movie|series)/([^/]+)/([^/]+)/(\d+)\.\w+$#', $path, $m)) {
    [, $kind, $user, $pass, $id] = $m;
    if (!creds_ok(urldecode($user), urldecode($pass))) {
        http_response_code(403);
        exit;
    }
    $id = (int) $id;
    $target = match ($kind) {
        'live' => ($id >= 1 && $id <= $LIVE_COUNT)
            ? mock_channel($id - 1)['url'] : null,
        'movie' => ($id - 1001 >= 0 && $id - 1001 < $MOVIE_COUNT)
            ? mock_movie($id - 1001)['url'] : null,
        'series' => $GLOBALS['EPISODES'][$id]['url'] ?? null,
    };
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
