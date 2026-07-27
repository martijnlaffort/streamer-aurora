import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/sync/sync_config.dart';
import '../../../data/sync/sync_providers.dart';
import '../../home/home_providers.dart';

/// Sync settings (PRD §8.12/§9): backend URL + shared token, an enable toggle,
/// and a manual "Sync now". Cross-device sync is optional; the app is fully
/// functional without it.
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() =>
      _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _baseUrl = TextEditingController();
  final _token = TextEditingController();
  bool _enabled = false;
  bool _loaded = false;
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _baseUrl.dispose();
    _token.dispose();
    super.dispose();
  }

  void _hydrate(SyncConfig config) {
    if (_loaded) return;
    _loaded = true;
    _baseUrl.text = config.baseUrl ?? 'https://';
    _token.text = config.token ?? '';
    _enabled = config.enabled;
  }

  Future<void> _save() async {
    final store = ref.read(syncConfigStoreProvider);
    final config = SyncConfig(
      baseUrl: _baseUrl.text.trim(),
      token: _token.text.trim(),
      enabled: _enabled,
    );
    await store.save(config);
    // Treat the enabling device's current prefs as authoritative initially.
    if (config.isConfigured) {
      await store.setPreferencesChangedAt(DateTime.now().toUtc());
    }
    ref.invalidate(syncConfigProvider);
    if (mounted) setState(() => _status = 'Saved.');
  }

  Future<void> _syncNow() async {
    await _save();
    setState(() {
      _busy = true;
      _status = 'Syncing…';
    });
    final result = await runSync(ref);
    ref.invalidate(homeDataProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = switch (result) {
        null => 'Sync is off or not configured.',
        _ when result.ok =>
          'Synced — pulled ${result.pulledProgress}, pushed ${result.pushedProgress}.',
        _ => 'Sync failed: ${result.error}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(syncConfigProvider);
    config.whenData(_hydrate);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sync watch progress, favorites, and preferences across your '
            'devices via your own server. Optional — Aurora works fully '
            'without it.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrl,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'https://sync.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Token',
              helperText: 'From `php artisan aurora:token` on the server',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable sync'),
            value: _enabled,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
