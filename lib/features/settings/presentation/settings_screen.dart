import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/db/app_database.dart' show CatalogKind;
import '../../../data/providers.dart';
import '../../../data/sources/playlist_source.dart' show SourceException;
import '../../../data/sources/tmdb_source.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../domain/models/models.dart';
import '../../home/home_providers.dart';

/// Cache row counts for the active account.
final cacheStatsProvider = FutureProvider<
    ({int channels, int movies, int series, int episodes})?>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  return ref.watch(catalogRepositoryProvider).cacheStats(account);
});

/// (code, display name) — the short list that covers real IPTV playlists.
/// null code = no preference; [Preferences.subsOff] = explicit off (subs).
const _languages = <(String?, String)>[
  (null, 'No preference'),
  ('en', 'English'),
  ('nl', 'Dutch'),
  ('de', 'German'),
  ('fr', 'French'),
  ('es', 'Spanish'),
  ('it', 'Italian'),
  ('tr', 'Turkish'),
  ('ar', 'Arabic'),
  ('pl', 'Polish'),
  ('pt', 'Portuguese'),
];

/// Sheet for the TMDB key + region behind the discovery rails.
///
/// The key is optional by design: with none, the bundled Award Winners rails
/// still work. Nothing about the user's playlist is sent to TMDB — only requests
/// for TMDB's own public lists — which is worth saying on screen, because
/// "paste an API key" otherwise reads as "upload my library".
Future<void> _editDiscovery(
  BuildContext context,
  WidgetRef ref,
  Preferences prefs,
  Future<void> Function(Preferences) savePrefs,
) async {
  final keyController = TextEditingController(text: prefs.tmdbApiKey ?? '');
  final regionController =
      TextEditingController(text: prefs.discoveryRegion ?? '');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Discovery rails',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Trending, Popular and New Releases come from TMDB\'s public '
            'lists, filtered to what your playlist actually carries. Your '
            'playlist is never uploaded. A free key takes a minute: '
            'themoviedb.org → Settings → API.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: keyController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'TMDB API key (v3)',
              hintText: 'Leave empty to use award rails only',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: regionController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            decoration: const InputDecoration(
              labelText: 'Region (2-letter country)',
              hintText: 'Empty = your device region',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                final key = keyController.text.trim();
                final region = regionController.text.trim().toUpperCase();
                // Check the key before saving. Pasting a key and being told
                // nothing is the worst part of this screen — a wrong key just
                // meant the rails silently never appeared.
                if (key.isNotEmpty) {
                  try {
                    await TmdbSource(apiKey: key).verifyKey();
                  } on SourceException catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(e.message)));
                    }
                    return;
                  }
                }
                await savePrefs(key.isEmpty
                    ? prefs.copyWith(
                        clearTmdbApiKey: true,
                        discoveryRegion: region.isEmpty ? null : region)
                    : prefs.copyWith(
                        tmdbApiKey: key,
                        discoveryRegion: region.isEmpty ? null : region));
                // New key/region → refetch the lists and re-resolve.
                ref.invalidate(discoveryRailsProvider);
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                      content: Text(key.isEmpty
                          ? 'Discovery rails limited to award winners.'
                          : 'TMDB key verified — discovery rails are on.')));
                  Navigator.of(sheetContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ),
  );
  keyController.dispose();
  regionController.dispose();
}

String _languageLabel(String? code) {
  if (code == null) return 'No preference';
  if (code == Preferences.subsOff) return 'Off';
  return _languages
          .where((l) => l.$1 == code)
          .map((l) => l.$2)
          .firstOrNull ??
      code;
}

/// Settings (PRD §8.12): accounts, favorites, playback languages,
/// autoplay, cache maintenance.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String? current,
    required bool withOff,
    required Future<void> Function(String?) onPicked,
  }) async {
    final options = [
      ..._languages,
      if (withOff) (Preferences.subsOff, 'Off (no subtitles)'),
    ];
    final picked = await showDialog<(String?,)>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        children: [
          for (final (code, label) in options)
            RadioListTile<String?>(
              value: code,
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (_) => Navigator.pop(context, (code,)),
              title: Text(label),
              activeColor: AppColors.accent,
            ),
        ],
      ),
    );
    if (picked != null) await onPicked(picked.$1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider);
    final prefs = ref.watch(preferencesProvider).value ??
        const Preferences.defaults();
    final stats = ref.watch(cacheStatsProvider);
    final prefsRepo = ref.read(preferencesRepositoryProvider);

    Future<void> savePrefs(Preferences updated) async {
      await prefsRepo.save(updated);
      // Stamp the local edit so sync's last-write-wins favours it (§9).
      await ref
          .read(syncConfigStoreProvider)
          .setPreferencesChangedAt(DateTime.now().toUtc());
      ref.invalidate(preferencesProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Library'),
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Accounts'),
            subtitle: Text(
              switch (active) {
                AsyncData(value: final a?) => 'Active: ${a.name}',
                _ => 'No active account',
              },
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Favorites'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/favorites'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About & credits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync'),
            subtitle: Text(
              (ref.watch(syncConfigProvider).value?.isConfigured ?? false)
                  ? 'On — across your devices'
                  : 'Off',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: const Text('Content languages'),
            subtitle: Text(
              prefs.contentLanguages == null
                  ? 'All languages'
                  : '${prefs.contentLanguages!.length} selected',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/languages'),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Discovery rails'),
            subtitle: Text(
              prefs.tmdbApiKey == null
                  ? 'Award winners only — add a TMDB key for Trending & Popular'
                  : 'On — trending, popular and new in '
                      '${prefs.discoveryRegion ?? 'your region'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editDiscovery(context, ref, prefs, savePrefs),
          ),
          const Divider(),
          const _SectionLabel('Playback'),
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: const Text('Preferred audio language'),
            subtitle: Text(_languageLabel(prefs.preferredAudioLang),
                style: const TextStyle(color: AppColors.accentAlt)),
            onTap: () => _pickLanguage(
              context,
              ref,
              title: 'Preferred audio language',
              current: prefs.preferredAudioLang,
              withOff: false,
              onPicked: (code) =>
                  savePrefs(prefs.copyWith(preferredAudioLang: code)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('Preferred subtitle language'),
            subtitle: Text(_languageLabel(prefs.preferredSubtitleLang),
                style: const TextStyle(color: AppColors.accentAlt)),
            onTap: () => _pickLanguage(
              context,
              ref,
              title: 'Preferred subtitle language',
              current: prefs.preferredSubtitleLang,
              withOff: true,
              onPicked: (code) =>
                  savePrefs(prefs.copyWith(preferredSubtitleLang: code)),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next_outlined),
            title: const Text('Autoplay next episode'),
            value: prefs.autoplayNext,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => savePrefs(prefs.copyWith(autoplayNext: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.headphones_outlined),
            title: const Text('Continue audio in background'),
            subtitle: const Text('Keep playing when the app is minimised',
                style: TextStyle(color: AppColors.textSecondary)),
            value: prefs.backgroundPlayback,
            activeThumbColor: AppColors.accent,
            onChanged: (v) =>
                savePrefs(prefs.copyWith(backgroundPlayback: v)),
          ),
          const Divider(),
          const _SectionLabel('Cache'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Cached catalog'),
            subtitle: Text(
              switch (stats) {
                AsyncData(value: final s?) =>
                  '${s.channels} channels · ${s.movies} movies · '
                      '${s.series} series · ${s.episodes} episodes',
                _ => '—',
              },
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Force refresh'),
            subtitle: const Text('Refetch the full catalog from the source',
                style: TextStyle(color: AppColors.textSecondary)),
            onTap: () async {
              final account = await ref.read(activeAccountProvider.future);
              if (account == null || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Refreshing catalog…')));
              try {
                await ref.read(catalogRepositoryProvider).refreshCatalog(
                    account, kinds: CatalogKind.values.toSet());
                messenger.showSnackBar(
                    const SnackBar(content: Text('Catalog refreshed.')));
              } on Exception catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')));
              }
              ref.invalidate(cacheStatsProvider);
              ref.invalidate(homeDataProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear catalog cache'),
            subtitle: const Text('Progress and favorites are kept',
                style: TextStyle(color: AppColors.textSecondary)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear catalog cache?'),
                  content: const Text(
                      'The catalog will be refetched from the source on the '
                      'next load. Watch progress and favorites are kept.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (confirmed != true) return;
              final account = await ref.read(activeAccountProvider.future);
              if (account == null) return;
              await ref
                  .read(catalogRepositoryProvider)
                  .clearCatalogCache(account);
              ref.invalidate(cacheStatsProvider);
              ref.invalidate(homeDataProvider);
            },
          ),
          const Divider(),
          const _SectionLabel('Appearance'),
          const ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Theme'),
            subtitle: Text('Dark — the cinematic default (PRD §10)',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (kDebugMode) ...[
            const Divider(),
            const _SectionLabel('Developer'),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Source probe'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/dev/source-probe'),
            ),
          ],
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Aurora',
            applicationVersion: '0.1.0',
            child: Text('About'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600)),
    );
  }
}
