<?php

use App\Http\Controllers\Api\FavoritesController;
use App\Http\Controllers\Api\PreferencesController;
use App\Http\Controllers\Api\ProgressController;
use Illuminate\Support\Facades\Route;

// Aurora sync API (PRD §9). Every route needs the shared Sanctum token:
//   Authorization: Bearer <token>
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/progress', [ProgressController::class, 'index']);
    Route::post('/progress', [ProgressController::class, 'store']);

    Route::get('/preferences', [PreferencesController::class, 'show']);
    Route::put('/preferences', [PreferencesController::class, 'update']);

    Route::get('/favorites', [FavoritesController::class, 'index']);
    Route::post('/favorites', [FavoritesController::class, 'store']);
    Route::delete('/favorites/{contentKey}', [FavoritesController::class, 'destroy'])
        ->where('contentKey', '.*');
});
