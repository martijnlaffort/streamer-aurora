<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

/**
 * Creates (or reuses) the single sync user and prints a fresh token to paste
 * into Aurora on each device. Run: `php artisan aurora:token`.
 */
class MakeSyncToken extends Command
{
    protected $signature = 'aurora:token {--name=device : a label for this token}';
    protected $description = 'Mint a Sanctum token for Aurora sync';

    public function handle(): int
    {
        $user = User::firstOrCreate(
            ['email' => 'aurora@sync.local'],
            ['name' => 'Aurora', 'password' => bcrypt(Str::random(40))],
        );

        $token = $user->createToken($this->option('name'))->plainTextToken;

        $this->info('Paste this token into Aurora → Settings → Sync:');
        $this->line('');
        $this->line($token);
        $this->line('');

        return self::SUCCESS;
    }
}
