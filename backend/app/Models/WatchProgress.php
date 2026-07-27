<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WatchProgress extends Model
{
    protected $table = 'watch_progress';

    protected $fillable = [
        'user_id', 'content_key', 'position_seconds', 'duration_seconds',
        'completed', 'updated_at_utc',
    ];

    protected $casts = [
        'completed' => 'boolean',
        'updated_at_utc' => 'datetime',
    ];
}
