<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Aurora sync tables (PRD §9). One row-set per user; a personal deployment
 * has a single user whose Sanctum token every device shares.
 *
 * All timestamps are stored UTC. Reconciliation is last-write-wins by
 * updated_at, so it is a real column, not just Eloquent bookkeeping.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('watch_progress', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('content_key');       // account:type:id
            $table->integer('position_seconds');
            $table->integer('duration_seconds');
            $table->boolean('completed')->default(false);
            $table->timestamp('updated_at_utc'); // client's UTC edit time (LWW key)
            $table->timestamps();
            $table->unique(['user_id', 'content_key']);
            $table->index(['user_id', 'updated_at_utc']);
        });

        Schema::create('favorites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('content_key');
            $table->timestamp('added_at_utc');
            $table->timestamps();
            $table->unique(['user_id', 'content_key']);
        });

        Schema::create('preferences', function (Blueprint $table) {
            $table->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();
            $table->string('preferred_audio_lang')->nullable();
            $table->string('preferred_subtitle_lang')->nullable();
            $table->boolean('autoplay_next')->default(true);
            $table->boolean('background_playback')->default(false);
            $table->timestamp('updated_at_utc');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('preferences');
        Schema::dropIfExists('favorites');
        Schema::dropIfExists('watch_progress');
    }
};
