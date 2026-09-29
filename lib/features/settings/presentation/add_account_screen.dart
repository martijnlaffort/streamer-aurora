import 'dart:io' show InternetAddress;

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
    final raw = _server.text.trim();
    // An Xtream server is a base URL. A trailing slash doesn't stop playback
    // (the client strips one when it builds requests), but it DOES change the
    // derived account id, so "host" and "host/" would be treated as two
    // different accounts that never share history. Normalise it away here. M3U's
    // field is a full playlist URL or a file path, so leave that untouched.
    final server = _type == AccountType.xtream
        ? raw.replaceFirst(RegExp(r'/+$'), '')
        : raw;
    // The host names the playlist when the user did not — but not a bare IP
    // address, which reads as nothing ("10.0.2.2") in the account list.
    final host = Uri.tryParse(server)?.host ?? '';
    final fallbackName = InternetAddress.tryParse(host) == null ? host : '';
    final username = _type == AccountType.xtream ? _username.text.trim() : '';
    return Account(
      // Derived from the playlist, never from the clock — so re-adding the same
      // source keeps its history, and a second device lands on the same id.
      id: stableAccountId(
          type: _type, serverUrl: server, username: username),
      type: _type,
      name: _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : (fallbackName.isNotEmpty ? fallbackName : 'My playlist'),
      serverUrl: server,
      username: username,
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
      if (!mounted) return;
      setState(() {
        _flow = _Flow.editing;
        _error = e.message;
      });
      return;
    } on FormatException catch (e) {
      // A malformed address fails inside Uri parsing before the source can
      // turn it into a SourceException. Uncaught, it left this button on
      // "Validating…" for good — seen on the TV emulator.
      if (!mounted) return;
      setState(() {
        _flow = _Flow.editing;
        _error = 'That address is not a valid URL (${e.message}).';
      });
      return;
    } on Object catch (e) {
      // Anything else (a socket error, a certificate problem) used to escape
      // and leave the button spinning for good as well.
      debugPrint('[dawn] add playlist failed: $e');
      if (!mounted) return;
      setState(() {
        _flow = _Flow.editing;
        _error = 'Couldn’t connect. Check the details and that this device '
            'is online, then try again.';
      });
      return;
    }
    if (!mounted) return;

    final accounts = ref.read(accountRepositoryProvider);
    await accounts.saveAccount(account);
    await accounts.setActiveAccount(account.id);
    if (!mounted) return;
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);

    // Cache the catalog with visible per-slice progress.
    setState(() {
      _flow = _Flow.caching;
      _progress = [
        _KindProgress(CatalogKind.live, 'Live channels'),
        _KindProgress(CatalogKind.vod, 'Films'),
        _KindProgress(CatalogKind.series, 'Series'),
      ];
    });
    final catalog = ref.read(catalogRepositoryProvider);
    for (final p in _progress) {
      if (!mounted) return;
      setState(() => p.status = _KindStatus.running);
      try {
        // Seed, don't sweep. Pulling every slice in full is minutes of waiting
        // on a large playlist before the app is usable at all; browsing fetches
        // the rest per category as you open it.
        await catalog.prepareSlice(account, p.kind);
        // COUNT in SQL — loading the rows just to count them held the whole
        // catalog in memory, which on a big playlist was enough to get the
        // app killed right here during onboarding.
        final stats = await catalog.cacheStats(account);
        p.count = switch (p.kind) {
          CatalogKind.live => stats.channels,
          CatalogKind.vod => stats.movies,
          CatalogKind.series => stats.series,
        };
        if (!mounted) return;
        setState(() => p.status = _KindStatus.done);
      } on Object catch (e) {
        // One slice failing shouldn't sink the account — keep going. Any
        // error, not just a SourceException: an uncaught one stopped the loop
        // and left "Getting…" on screen with no way on.
        if (!mounted) return;
        setState(() {
          p.status = _KindStatus.failed;
          p.error = e is SourceException
              ? e.message
              : 'Couldn’t fetch these — they will load when you open them.';
        });
      }
    }
    if (mounted) setState(() => _flow = _Flow.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a playlist')),
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
      // Named for what the provider sent, not the protocol: "Xtream" and
      // "M3U" mean nothing to most people setting this up.
      SegmentedButton<AccountType>(
        segments: const [
          ButtonSegment(
              value: AccountType.xtream,
              label: Text('Login details'),
              icon: Icon(Icons.dns_outlined)),
          ButtonSegment(
              value: AccountType.m3u,
              label: Text('Playlist link'),
              icon: Icon(Icons.link)),
        ],
        selected: {_type},
        onSelectionChanged: validating
            ? null
            : (s) => setState(() => _type = s.first),
      ),
      const SizedBox(height: 8),
      Text(
        _type == AccountType.xtream
            ? 'Your provider sent a server address, a username and a password '
                '(sometimes called Xtream Codes).'
            : 'Your provider sent a single link, usually ending in .m3u or '
                '.m3u8.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
          labelText: _type == AccountType.xtream
              ? 'Server address'
              : 'Playlist link (or file)',
          hintText: _type == AccountType.xtream
              ? 'http://provider.example:8080'
              : 'http://provider.example/playlist.m3u',
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
            labelText: 'Programme guide link (optional)',
            helperText: 'An XMLTV link, if your provider gave you one',
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
          child: Text(_error!, style: TextStyle(color: AppColors.error)),
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
                  Text('Connecting…'),
                ],
              )
            : const Text('Connect'),
      ),
    ];
  }

  List<Widget> _cachingProgress() {
    return [
      Text('Getting your channels and films',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Saved on this device once, so browsing is instant — even offline.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      for (final p in _progress)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: switch (p.status) {
            _KindStatus.pending => Icon(Icons.circle_outlined,
                color: AppColors.textSecondary),
            _KindStatus.running => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
            _KindStatus.done =>
              Icon(Icons.check_circle, color: AppColors.accentAlt),
            _KindStatus.failed =>
              Icon(Icons.error_outline, color: AppColors.error),
          },
          title: Text(p.label),
          subtitle: switch (p.status) {
            _KindStatus.done => Text('${p.count} found',
                style: TextStyle(color: AppColors.textSecondary)),
            _KindStatus.failed => Text(p.error ?? 'failed',
                style: TextStyle(color: AppColors.error)),
            _ => null,
          },
        ),
      const SizedBox(height: 16),
      FilledButton(
        // Home, not back to the Accounts list: the point of adding a playlist
        // is to watch it.
        autofocus: true,
        onPressed: _flow == _Flow.done ? () => context.go('/') : null,
        child: Text(_flow == _Flow.done ? 'Start watching' : 'Getting…'),
      ),
    ];
  }
}
