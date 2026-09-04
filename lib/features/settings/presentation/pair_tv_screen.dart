import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/sync/pairing_service.dart';
import '../../../data/sync/sync_providers.dart';
import 'pair_scan_screen.dart';

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

  /// [backend] is the server the television opened its session on, when a scan
  /// told us. The claim has to land there or the TV never sees it. The payload
  /// still carries THIS phone's sync settings, so the TV ends up syncing with
  /// the same server the phone does.
  Future<void> _send({String? backend}) async {
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
      await PairingService(baseUrl: backend ?? baseUrl).claim(
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

  /// Camera path: reads the code and the backend off the television's QR and
  /// sends straight away — nothing to type, nothing to confirm.
  Future<void> _scan() async {
    final result = await Navigator.of(context).push<PairScan>(
        MaterialPageRoute(builder: (_) => const PairScanScreen()));
    if (result == null || !mounted) return;
    setState(() => _code.text = result.code);
    await _send(backend: result.backend);
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
                  Icon(Icons.check_circle_outline,
                      color: AppColors.accentAlt),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_done!, style: AppTypography.body),
                        const SizedBox(height: 4),
                        Text('Your TV should be ready now.',
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
          Text(
            'On your TV, open Dawn Player and go to Settings → Pair with your '
            'phone. Enter the code it shows here, or scan the square beside it.',
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
            // The Send button below reads the length; without this it would
            // only wake up on submit.
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _send(),
          ),
          // Phones only: a television has no camera to point, and the desktop
          // build has no scanner. The typed code stays for both.
          if (!isTelevisionOf(ref) &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sending ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan the code on the TV instead'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.error)),
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
          Text(
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
