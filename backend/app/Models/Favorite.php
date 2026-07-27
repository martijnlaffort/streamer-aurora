<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Favorite extends Model
{
    protected $fillable = ['user_id', 'content_key', 'added_at_utc'];

    protected $casts = ['added_at_utc' => 'datetime'];
}
