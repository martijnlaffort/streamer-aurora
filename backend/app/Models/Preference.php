<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Preference extends Model
{
    protected $primaryKey = 'user_id';
    public $incrementing = false;

    protected $fillable = [
        'user_id', 'preferred_audio_lang', 'preferred_subtitle_lang',
        'autoplay_next', 'background_playback', 'updated_at_utc',
    ];

    protected $casts = [
        'autoplay_next' => 'boolean',
        'background_playback' => 'boolean',
        'updated_at_utc' => 'datetime',
    ];
}
