<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Favorite;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class FavoritesController extends Controller
{
    /** GET /api/favorites */
    public function index(Request $request)
    {
        return response()->json([
            'favorites' => Favorite::where('user_id', $request->user()->id)
                ->get()
                ->map(fn ($f) => [
                    'content_key' => $f->content_key,
                    'added_at' => $f->added_at_utc->toIso8601String(),
                ]),
        ]);
    }

    /** POST /api/favorites — add (idempotent). */
    public function store(Request $request)
    {
        $data = $request->validate([
            'content_key' => ['required', 'string'],
            'added_at' => ['nullable', 'date'],
        ]);

        Favorite::firstOrCreate(
            ['user_id' => $request->user()->id, 'content_key' => $data['content_key']],
            ['added_at_utc' => isset($data['added_at'])
                ? Carbon::parse($data['added_at'])
                : now()],
        );

        return response()->json(['ok' => true]);
    }

    /** DELETE /api/favorites/{contentKey} */
    public function destroy(Request $request, string $contentKey)
    {
        Favorite::where('user_id', $request->user()->id)
            ->where('content_key', $contentKey)
            ->delete();

        return response()->json(['ok' => true]);
    }
}
