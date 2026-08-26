import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../player/presentation/player_screen.dart' show kStreamUserAgent;

/// Per-playlist network settings: which `User-Agent` its streams are requested
/// with, and which other hosts to fall back to.
///
/// A separate screen from "add account" on purpose — both of these matter most
/// for a playlist that already exists and has started misbehaving, which is
/// exactly when the add flow is no longer reachable.
class AccountNetworkScreen extends ConsumerStatefulWidget {
  const AccountNetworkScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountNetworkScreen> createState() =>
      _AccountNetworkScreenState();
}

/// Strings that panels are known to accept. A panel that refuses libmpv's
/// default will usually take one of these, and typing them by hand from memory
/// is how the last few hours of debugging started.
const _presets = <(String, String)>[
  ('VLC', 'VLC/3.0.21 LibVLC/3.0.21'),
  ('TiviMate', 'TiviMate/5.0.0 (Android)'),
  ('Kodi', 'Kodi/20.2 (Android)'),
  ('Smarters', 'IPTVSmartersPlayer/1.0'),
];

class _AccountNetworkScreenState extends ConsumerState<AccountNetworkScreen> {
  final _userAgent = TextEditingController();
  final _altHosts = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _userAgent.dispose();
    _altHosts.dispose();
    super.dispose();
  }

  void _fill(Account account) {
    if (_loaded) return;
    _loaded = true;
    _userAgent.text = account.userAgent ?? '';
    _altHosts.text = account.altHosts.join('\n');
  }

  Future<void> _save(Account account) async {
    setState(() => _saving = true);
    final agent = _userAgent.text.trim();
    final updated = account.copyWith(
      userAgent: agent.isEmpty ? null : agent,
      clearUserAgent: agent.isEmpty,
      altHosts: [
        for (final line in _altHosts.text.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ],
    );
    await ref.read(accountRepositoryProvider).saveAccount(updated);
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final account = accounts.value
        ?.where((a) => a.id == widget.accountId)
        .firstOrNull;
    if (account != null) _fill(account);

    return Scaffold(
      appBar: AppBar(title: const Text('Streaming & hosts')),
      body: account == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(account.name, style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                const Text('User-Agent',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Many panels serve the catalogue to anyone but only hand over '
                  'the video to a player they recognise. If the catalogue loads '
                  'and every stream fails, this is the first thing to change.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userAgent,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'User-Agent',
                    hintText: kStreamUserAgent,
                    helperText: 'Empty uses the app default',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, value) in _presets)
                      ActionChip(
                        label: Text(label),
                        onPressed: () =>
                            setState(() => _userAgent.text = value),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Fallback hosts',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'One per line. When a stream will not open, the same request '
                  'is retried against each of these in turn before giving up. '
                  'Providers hand out several hostnames and they are not '
                  'interchangeable — one can be blocked or badly routed while '
                  'another works.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _altHosts,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Fallback hosts',
                    hintText: 'backup.provider.tv:8080\nhttp://alt.provider.tv',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(account),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
    );
  }
}
