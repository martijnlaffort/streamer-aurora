<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WatchProgress;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ProgressController extends Controller
{
    /** GET /api/progress?since=ISO8601 — entries changed since `since`. */
    public function index(Request $request)
    {
        $query = WatchProgress::where('user_id', $request->user()->id);
        if ($since = $request->query('since')) {
            $query->where('updated_at_utc', '>', Carbon::parse($since));
        }

        return response()->json([
            'entries' => $query->get()->map(fn ($p) => [
                'content_key' => $p->content_key,
                'position_seconds' => $p->position_seconds,
                'duration_seconds' => $p->duration_seconds,
                'completed' => $p->completed,
                'updated_at' => $p->updated_at_utc->toIso8601String(),
            ]),
        ]);
    }

    /** POST /api/progress — upsert a batch; last-write-wins by updated_at. */
    public function store(Request $request)
    {
        $data = $request->validate([
            'entries' => ['required', 'array'],
            'entries.*.content_key' => ['required', 'string'],
            'entries.*.position_seconds' => ['required', 'integer'],
            'entries.*.duration_seconds' => ['required', 'integer'],
            'entries.*.completed' => ['required', 'boolean'],
            'entries.*.updated_at' => ['required', 'date'],
        ]);

        $userId = $request->user()->id;
        foreach ($data['entries'] as $e) {
            $incoming = Carbon::parse($e['updated_at']);
            $existing = WatchProgress::where('user_id', $userId)
                ->where('content_key', $e['content_key'])->first();

            // Only apply when the incoming edit is newer (or new).
            if ($existing && $existing->updated_at_utc->greaterThanOrEqualTo($incoming)) {
                continue;
            }
            WatchProgress::updateOrCreate(
                ['user_id' => $userId, 'content_key' => $e['content_key']],
                [
                    'position_seconds' => $e['position_seconds'],
                    'duration_seconds' => $e['duration_seconds'],
                    'completed' => $e['completed'],
                    'updated_at_utc' => $incoming,
                ],
            );
        }

        return response()->json(['ok' => true]);
    }
}
