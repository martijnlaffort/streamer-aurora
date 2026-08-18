import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/providers.dart';
import '../../../data/sync/pairing_service.dart';
import '../../../data/sync/sync_providers.dart';
import '../../home/home_providers.dart';

/// The receiving side of pairing — normally the TV.
///
/// Shows a short code and waits for a configured phone to send its playlists
/// and sync settings, so nothing has to be typed on a remote.
class PairDeviceScreen extends ConsumerStatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  /// Baked in at build time so a television never has to type a URL. Empty in
  /// a plain build, in which case we ask for it once.
  static const _bakedBaseUrl =
      String.fromEnvironment('DAWN_SYNC_URL', defaultValue: '');

  final _baseUrl = TextEditingController();
  PairingSession? _session;
  Timer? _poll;
  Object? _error;
  bool _starting = false;
  String? _done;

  @override
  void initState() {
    super.initState();
    _baseUrl.text = _bakedBaseUrl;
    // Prefer an already-configured backend, then the build-time default. Only
    // ask when we have neither.
    ref.read(syncConfigProvider.future).then((config) {
      if (!mounted) return;
      final existing = config.baseUrl?.trim() ?? '';
      if (existing.isNotEmpty && existing != 'https://') {
        _baseUrl.text = existing;
      }
      if (_baseUrl.text.trim().isNotEmpty) _start();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final base = _baseUrl.text.trim();
    if (base.isEmpty) return;
    setState(() {
      _starting = true;
      _error = null;
      _done = null;
    });
    try {
      final service = PairingService(baseUrl: base);
      final session = await service.open();
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
      });
      // Every three seconds: slow enough to sit inside the server's poll
      // budget, fast enough that pairing feels immediate once the phone sends.
      _poll?.cancel();
      _poll = Timer.periodic(
          const Duration(seconds: 3), (_) => _check(service, session));
    } on Object catch (e) {
      if (mounted) setState(() => (_error = e, _starting = false));
    }
  }

  Future<void> _check(PairingService service, PairingSession session) async {
    try {
      final payload =
          await service.collect(session, DateTime.now().toUtc());
      if (payload == null || !mounted) return;
      _poll?.cancel();
      await _apply(payload);
    } on Object catch (e) {
      _poll?.cancel();
      if (mounted) setState(() => _error = e);
    }
  }

  /// Writes the received configuration to this device.
  Future<void> _apply(PairingPayload payload) async {
    final accounts = ref.read(accountRepositoryProvider);
    for (final account in payload.accounts) {
      // saveAccount is an upsert keyed by the derived id, so pairing twice, or
      // pairing a playlist that was already added by hand, changes nothing.
      await accounts.saveAccount(account);
    }
    if (payload.accounts.isNotEmpty) {
      await accounts.setActiveAccount(payload.accounts.first.id);
    }
    final sync = payload.sync;
    var pulled = false;
    if (sync != null && (sync.token?.isNotEmpty ?? false)) {
      await ref.read(syncConfigStoreProvider).save(sync);
      ref.invalidate(syncConfigProvider);
      ref.invalidate(syncServiceProvider);
      // Pull watch history and favourites now. Pairing brings the account and
      // the sync credentials, but Continue Watching and My List live on the
      // sync backend, NOT in the pairing payload — without this they stay empty
      // until the next launch, and the "watch history is on this device now"
      // message below would simply be false. A backend that is unreachable, or
      // a phone that has not pushed yet, just leaves them empty rather than
      // failing the pairing.
      try {
        final result = await runSync(ref);
        pulled = result?.ok ?? false;
      } on Object {
        // Non-fatal: the account and sync config are saved either way, and the
        // next launch or a manual Sync now will pull the history.
      }
    }
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);
    // The rails are resolved from what was just pulled.
    ref.invalidate(homeDataProvider);
    ref.invalidate(myListProvider);
    if (!mounted) return;
    setState(() {
      final n = payload.accounts.length;
      _done = 'Paired. ${n == 1 ? '1 playlist' : '$n playlists'} added'
          '${sync?.token?.isNotEmpty ?? false ? ', sync switched on' : ''}'
          '${pulled ? '. Watch history and My List synced' : ''}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with your phone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_done != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.accentAlt, size: 48),
          const SizedBox(height: 16),
          Text(_done!, textAlign: TextAlign.center, style: AppTypography.title),
          const SizedBox(height: 8),
          const Text(
            'If Continue Watching or My List look empty, open Settings → Sync '
            'on your phone and tap Sync now, then Sync now here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: _start);
    }
    if (_baseUrl.text.trim().isEmpty && _session == null && !_starting) {
      // Only reached in a build with no baked-in backend and no sync set up.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Where does your sync server live?',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Backend URL',
              hintText: 'https://sync.example.com',
            ),
            onSubmitted: (_) => _start(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _start, child: const Text('Continue')),
        ],
      );
    }
    if (_starting || _session == null) {
      return const CircularProgressIndicator(color: AppColors.accent);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('On your phone, open Dawn Player and go to',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Settings → Set up a TV', style: AppTypography.title),
        const SizedBox(height: 28),
        const Text('Then enter this code:',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            // Spaced out: this is read across a room and typed on a phone.
            _session!.code.split('').join(' '),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent)),
            SizedBox(width: 10),
            Text('Waiting for your phone…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('The code expires in 10 minutes.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
