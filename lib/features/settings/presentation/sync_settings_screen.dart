import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/sync/sync_config.dart';
import '../../../data/sync/sync_providers.dart';
import '../../home/home_providers.dart';

/// Sync settings (PRD §8.12/§9): backend URL + shared token, an enable toggle.
///
/// There is no "Sync now" — sync runs automatically (on launch, on resume, in
/// the background, and shortly after any change). This screen only exists to
/// enter the server details when NOT setting up via pairing, and to turn sync
/// off. Cross-device sync is optional; the app is fully functional without it.
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

  /// Saves the config and kicks an immediate sync so the user gets confirmation
  /// it works — this is part of saving, not a standalone manual sync. From here
  /// on it is automatic.
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
    ref.invalidate(syncServiceProvider);
    if (!config.isConfigured) {
      if (mounted) setState(() => _status = 'Saved. Sync is off.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Saved. Checking the connection…';
    });
    final result = await runSync(ref);
    ref.invalidate(homeDataProvider);
    ref.invalidate(myListProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = switch (result) {
        null => 'Saved, but sync is off or not configured.',
        _ when result.ok =>
          'Connected. Syncing automatically from now on.',
        _ => 'Could not reach the server: ${result.error}',
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
          Text(
            'Sync watch progress, favorites, and preferences across your '
            'devices via your own server — automatically, in the background. '
            'Optional; Dawn Player works fully without it. Usually there is '
            'nothing to do here: pairing a device fills this in for you.',
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
              // Still `aurora:token`: that is the command name registered by the
              // deployed backend. Renaming it here would print an instruction
              // that fails on the server until the backend is redeployed.
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
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Save'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
