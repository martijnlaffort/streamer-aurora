import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/db/app_database.dart' show CatalogKind;
import '../../../data/providers.dart';
import '../../../data/sources/playlist_source.dart';
import '../../../domain/models/models.dart';

enum _Flow { editing, validating, caching, done }

enum _KindStatus { pending, running, done, failed }

class _KindProgress {
  _KindProgress(this.kind, this.label);

  final CatalogKind kind;
  final String label;
  _KindStatus status = _KindStatus.pending;
  int count = 0;
  String? error;
}

/// Add an Xtream or M3U account (PRD §8.1): validate on save, then cache the
/// catalog with visible per-slice progress.
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  AccountType _type = AccountType.xtream;
  final _name = TextEditingController();
  final _server = TextEditingController(text: 'http://');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _epgUrl = TextEditingController();

  _Flow _flow = _Flow.editing;
  String? _error;
  List<_KindProgress> _progress = [];

  @override
  void dispose() {
    for (final c in [_name, _server, _username, _password, _epgUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Account _buildAccount() {
    final server = _server.text.trim();
    final fallbackName = Uri.tryParse(server)?.host ?? '';
    return Account(
      id: 'acc_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      type: _type,
      name: _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : (fallbackName.isNotEmpty ? fallbackName : 'My playlist'),
      serverUrl: server,
      username: _type == AccountType.xtream ? _username.text.trim() : '',
      password: _type == AccountType.xtream ? _password.text : '',
      createdAt: DateTime.now().toUtc(),
      epgUrl: _type == AccountType.m3u && _epgUrl.text.trim().isNotEmpty
          ? _epgUrl.text.trim()
          : null,
    );
  }

  Future<void> _save() async {
    final account = _buildAccount();
    setState(() {
      _flow = _Flow.validating;
      _error = null;
    });

    // Validate on save: Xtream auth ping / M3U parse check (PRD §8.1).
    try {
      await ref.read(sourceFactoryProvider)(account).authenticate();
    } on SourceException catch (e) {
      setState(() {
        _flow = _Flow.editing;
        _error = e.message;
      });
      return;
    }

    final accounts = ref.read(accountRepositoryProvider);
    await accounts.saveAccount(account);
    await accounts.setActiveAccount(account.id);
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);

    // Cache the catalog with visible per-slice progress.
    setState(() {
      _flow = _Flow.caching;
      _progress = [
        _KindProgress(CatalogKind.live, 'Live channels'),
        _KindProgress(CatalogKind.vod, 'Movies'),
        _KindProgress(CatalogKind.series, 'Series'),
      ];
    });
    final catalog = ref.read(catalogRepositoryProvider);
    for (final p in _progress) {
      setState(() => p.status = _KindStatus.running);
      try {
        await catalog.refreshCatalog(account, kinds: {p.kind});
        p.count = switch (p.kind) {
          CatalogKind.live => (await catalog.channels(account)).length,
          CatalogKind.vod => (await catalog.movies(account)).length,
          CatalogKind.series => (await catalog.series(account)).length,
        };
        setState(() => p.status = _KindStatus.done);
      } on SourceException catch (e) {
        // One slice failing shouldn't sink the account — keep going.
        setState(() {
          p.status = _KindStatus.failed;
          p.error = e.message;
        });
      }
    }
    setState(() => _flow = _Flow.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: switch (_flow) {
            _Flow.editing || _Flow.validating => _form(),
            _Flow.caching || _Flow.done => _cachingProgress(),
          },
        ),
      ),
    );
  }

  List<Widget> _form() {
    final validating = _flow == _Flow.validating;
    return [
      SegmentedButton<AccountType>(
        segments: const [
          ButtonSegment(
              value: AccountType.xtream,
              label: Text('Xtream'),
              icon: Icon(Icons.dns_outlined)),
          ButtonSegment(
              value: AccountType.m3u,
              label: Text('M3U'),
              icon: Icon(Icons.playlist_play)),
        ],
        selected: {_type},
        onSelectionChanged: validating
            ? null
            : (s) => setState(() => _type = s.first),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        enabled: !validating,
        decoration: const InputDecoration(
          labelText: 'Name (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _server,
        enabled: !validating,
        autocorrect: false,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText:
              _type == AccountType.xtream ? 'Server URL' : 'Playlist URL or file',
          border: const OutlineInputBorder(),
        ),
      ),
      if (_type == AccountType.xtream) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          enabled: !validating,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !validating,
          autocorrect: false,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
      ] else ...[
        const SizedBox(height: 12),
        TextField(
          controller: _epgUrl,
          enabled: !validating,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'XMLTV EPG URL (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: validating ? null : _save,
        child: validating
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Validating…'),
                ],
              )
            : const Text('Validate & save'),
      ),
    ];
  }

  List<Widget> _cachingProgress() {
    return [
      Text('Caching catalog',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Fetching everything once so browsing is instant — even offline.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      for (final p in _progress)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: switch (p.status) {
            _KindStatus.pending => const Icon(Icons.circle_outlined,
                color: AppColors.textSecondary),
            _KindStatus.running => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
            _KindStatus.done =>
              const Icon(Icons.check_circle, color: AppColors.accentAlt),
            _KindStatus.failed =>
              const Icon(Icons.error_outline, color: AppColors.error),
          },
          title: Text(p.label),
          subtitle: switch (p.status) {
            _KindStatus.done => Text('${p.count} items',
                style: const TextStyle(color: AppColors.textSecondary)),
            _KindStatus.failed => Text(p.error ?? 'failed',
                style: const TextStyle(color: AppColors.error)),
            _ => null,
          },
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _flow == _Flow.done ? () => context.pop() : null,
        child: Text(_flow == _Flow.done ? 'Finish' : 'Caching…'),
      ),
    ];
  }
}
