<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Preference;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class PreferencesController extends Controller
{
    /** GET /api/preferences */
    public function show(Request $request)
    {
        $p = Preference::find($request->user()->id);
        if (! $p) {
            return response()->json(['preferences' => null]);
        }

        return response()->json(['preferences' => [
            'preferred_audio_lang' => $p->preferred_audio_lang,
            'preferred_subtitle_lang' => $p->preferred_subtitle_lang,
            'autoplay_next' => $p->autoplay_next,
            'background_playback' => $p->background_playback,
            'updated_at' => $p->updated_at_utc->toIso8601String(),
        ]]);
    }

    /** PUT /api/preferences — last-write-wins by updated_at. */
    public function update(Request $request)
    {
        $data = $request->validate([
            'preferred_audio_lang' => ['nullable', 'string'],
            'preferred_subtitle_lang' => ['nullable', 'string'],
            'autoplay_next' => ['required', 'boolean'],
            'background_playback' => ['required', 'boolean'],
            'updated_at' => ['required', 'date'],
        ]);

        $userId = $request->user()->id;
        $incoming = Carbon::parse($data['updated_at']);
        $existing = Preference::find($userId);
        if ($existing && $existing->updated_at_utc->greaterThanOrEqualTo($incoming)) {
            return response()->json(['ok' => true, 'applied' => false]);
        }

        Preference::updateOrCreate(
            ['user_id' => $userId],
            [
                'preferred_audio_lang' => $data['preferred_audio_lang'] ?? null,
                'preferred_subtitle_lang' => $data['preferred_subtitle_lang'] ?? null,
                'autoplay_next' => $data['autoplay_next'],
                'background_playback' => $data['background_playback'],
                'updated_at_utc' => $incoming,
            ],
        );

        return response()->json(['ok' => true, 'applied' => true]);
    }
}
