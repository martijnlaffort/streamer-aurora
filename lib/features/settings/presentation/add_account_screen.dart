import 'dart:io' show FileSystemException, InternetAddress;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/db/app_database.dart' show CatalogKind;
import '../../../data/local/playlist_files.dart';
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

/// Add a playlist or media server (PRD §8.1): validate on save, then cache the
/// catalog with visible per-slice progress.
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({
    super.key,
    this.initialType = AccountType.m3u,
    this.initialPlaylist,
  });

  /// Which form to open on. A playlist unless the viewer asked for a server.
  final AccountType initialType;

  /// A playlist file already imported into the app (see
  /// `importPlaylistFile`), e.g. one opened in Dawn Player from Files.
  final String? initialPlaylist;

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  late AccountType _type =
      widget.initialPlaylist != null ? AccountType.m3u : widget.initialType;
  final _name = TextEditingController();
  late final _server = TextEditingController(
      text: _type == AccountType.xtream ? 'http://' : '');

  /// A playlist FILE chosen instead of a link: its in-app location. The link
  /// field is hidden while one is set.
  late String? _playlistFile = widget.initialPlaylist;
  bool _importing = false;
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
    final file = _type == AccountType.m3u ? _playlistFile : null;
    final raw = file ?? _server.text.trim();
    // A media server is a base URL. A trailing slash doesn't stop playback
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
          : file != null
              ? _withoutExtension(playlistDisplayName(file))
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

  static String _withoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// "Choose a playlist file": the document picker, then a private copy.
  Future<void> _choosePlaylistFile() async {
    final pick = await ref.read(localMediaPlatformProvider).pickPlaylist();
    if (pick == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final location = await importPlaylistFile(pick);
      if (!mounted) return;
      setState(() {
        _playlistFile = location;
        _error = null;
      });
    } on FileSystemException {
      if (!mounted) return;
      setState(() => _error = 'Couldn’t read that file. Try choosing it again.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
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
        _KindProgress(CatalogKind.live, 'Live streams'),
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
    if (!mounted) return;
    // The Live and Series tabs exist only for a source that has them; now we
    // know.
    ref.invalidate(activeHasLiveProvider);
    ref.invalidate(activeHasSeriesProvider);
    setState(() => _flow = _Flow.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_type == AccountType.xtream
              ? 'Connect a media server'
              : 'Add a playlist')),
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
      // Named for what the user has in hand, not the protocol: protocol names
      // mean nothing to most people setting this up. Playlist first, server
      // second, matching the getting-started screen.
      SegmentedButton<AccountType>(
        segments: const [
          ButtonSegment(
              value: AccountType.m3u,
              label: Text('Playlist'),
              icon: Icon(Icons.playlist_play)),
          ButtonSegment(
              value: AccountType.xtream,
              label: Text('Media server'),
              icon: Icon(Icons.dns_outlined)),
        ],
        selected: {_type},
        onSelectionChanged: validating
            ? null
            : (s) => setState(() {
                  _type = s.first;
                  // The scheme is a useful head start for a server address and
                  // noise in front of a pasted playlist link.
                  final text = _server.text.trim();
                  if (_type == AccountType.xtream && text.isEmpty) {
                    _server.text = 'http://';
                  } else if (_type == AccountType.m3u && text == 'http://') {
                    _server.text = '';
                  }
                }),
      ),
      const SizedBox(height: 8),
      Text(
        _type == AccountType.xtream
            ? 'The address of a media server you use, with your username and '
                'password for it.'
            : 'A link to your playlist, usually ending in .m3u or .m3u8, or '
                'a playlist file on this device.',
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
      if (_type == AccountType.m3u && _playlistFile != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(playlistDisplayName(_playlistFile!)),
          subtitle: const Text('Playlist file on this device'),
          trailing: IconButton(
            tooltip: 'Use a link instead',
            icon: const Icon(Icons.close),
            onPressed:
                validating ? null : () => setState(() => _playlistFile = null),
          ),
        )
      else
        TextField(
          controller: _server,
          enabled: !validating,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: _type == AccountType.xtream
                ? 'Server address'
                : 'Playlist link',
            hintText: _type == AccountType.xtream
                ? 'http://server.example:8080'
                : 'https://example.com/playlist.m3u',
            border: const OutlineInputBorder(),
          ),
        ),
      if (_type == AccountType.m3u &&
          _playlistFile == null &&
          ref.watch(localMediaPlatformProvider).isSupported) ...[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: validating || _importing ? null : _choosePlaylistFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose a playlist file'),
          ),
        ),
      ],
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
            helperText: 'An XMLTV link, if your playlist comes with one',
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
      const SizedBox(height: 12),
      // Both stores ask players of user-supplied media to say this where the
      // source is added, not only in a policy nobody opens.
      Text(
        'Dawn Player includes no content. Only add sources you have the right '
        'to access.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ];
  }

  List<Widget> _cachingProgress() {
    return [
      Text('Getting your library',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Saved on this device once, so browsing is instant — even offline.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      // A kind the source turned out not to have is left out rather than
      // listed as "0 found": a playlist of films has no live streams, and
      // saying so reads as something missing.
      for (final p in _progress)
        if (!(p.status == _KindStatus.done && p.count == 0)) ListTile(
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
