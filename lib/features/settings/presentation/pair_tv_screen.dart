import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/sync/pairing_service.dart';
import '../../../data/sync/sync_providers.dart';

/// The sending side of pairing — the phone that is already set up.
///
/// Takes the code shown on the TV and pushes this device's playlists and sync
/// settings to it.
class PairTvScreen extends ConsumerStatefulWidget {
  const PairTvScreen({super.key});

  @override
  ConsumerState<PairTvScreen> createState() => _PairTvScreenState();
}

class _PairTvScreenState extends ConsumerState<PairTvScreen> {
  final _code = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final config = await ref.read(syncConfigProvider.future);
    final token = config.token?.trim() ?? '';
    final baseUrl = config.baseUrl?.trim() ?? '';
    if (token.isEmpty || baseUrl.isEmpty) {
      setState(() => _error =
          'Set up Settings → Sync on this phone first. Pairing sends those '
          'details to your TV, so this device needs them.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // getAccounts resolves each password from the keychain, which is what
      // makes the TV need no typing at all.
      final accounts = await ref.read(accountRepositoryProvider).getAccounts();
      if (accounts.isEmpty) {
        setState(() {
          _error = 'There are no playlists on this phone to send.';
          _sending = false;
        });
        return;
      }
      await PairingService(baseUrl: baseUrl).claim(
        code: _code.text,
        token: token,
        payload: PairingPayload(accounts: accounts, sync: config),
      );
      if (!mounted) return;
      setState(() {
        _done = accounts.length == 1
            ? 'Sent 1 playlist and your sync settings.'
            : 'Sent ${accounts.length} playlists and your sync settings.';
        _sending = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'.replaceFirst('SourceException: ', '');
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up a TV')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_done != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.accentAlt),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_done!, style: AppTypography.body),
                        const SizedBox(height: 4),
                        const Text('Your TV should be ready now.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'On your TV, open Aurora and go to Settings → Pair with your '
            'phone. Enter the code it shows here.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 6,
            style: const TextStyle(
                fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            inputFormatters: [
              // The alphabet the TV draws from — letters and digits only, and
              // always upper case, so a lower-case entry still matches.
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction((old, next) =>
                  next.copyWith(text: next.text.toUpperCase())),
            ],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Code from your TV',
              counterText: '',
            ),
            onSubmitted: (_) => _send(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending || _code.text.length < 6 ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cast),
            label: Text(_sending ? 'Sending…' : 'Send to TV'),
          ),
          const SizedBox(height: 24),
          const Text(
            'This sends your playlists — including their passwords — and your '
            'sync token, so nothing has to be typed on the TV. They pass '
            'through your own sync server and are deleted the moment the TV '
            'picks them up.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
