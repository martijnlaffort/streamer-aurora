import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/television.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/db/app_database.dart' show CatalogKind;
import '../../../data/notifications/reminder_service.dart';
import '../../../data/providers.dart';
import '../../../data/sources/playlist_source.dart' show SourceException;
import '../../../data/sources/tmdb_source.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../data/updates/update_service.dart';
import '../../../domain/models/models.dart';
import '../../home/home_providers.dart';
import 'update_notice.dart';

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
          Text(
            'Trending, Popular and New Releases come from TMDB\'s public '
            'lists, filtered to what your playlist actually carries. Your '
            'playlist is never uploaded. A free key takes a minute: '
            'themoviedb.org → Settings → API.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: keyController,
            autofocus: true,
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

/// Fine-tune for the part of an A/V offset the app cannot see.
///
/// The player already compensates for its own video latency automatically.
/// What is left is the screen's: a television's picture processing, a soundbar
/// over ARC. That differs per display and cannot be measured from inside the
/// app, so it is a control — steps rather than a slider, because a slider is
/// miserable with a remote and 10 ms is below what anyone can hear anyway.
Future<void> _editAudioDelay(
  BuildContext context,
  Preferences prefs,
  Future<void> Function(Preferences) savePrefs,
) async {
  var value = prefs.audioDelayMs;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Audio sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'If the sound runs ahead of the picture, delay it. If it lags '
              'behind, bring it forward. Applies to this screen only.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Sound earlier',
                  onPressed: value > -300
                      ? () => setState(() => value -= 10)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    value == 0
                        ? 'Automatic'
                        : '${value > 0 ? '+' : ''}$value ms',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Sound later',
                  onPressed: value < 300
                      ? () => setState(() => value += 10)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value > 0
                  ? 'Sound delayed'
                  : value < 0
                      ? 'Sound brought forward'
                      : 'Only the app\'s own latency is corrected',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (value != 0)
            TextButton(
              onPressed: () => setState(() => value = 0),
              child: const Text('Reset'),
            ),
          FilledButton(
            autofocus: true,
            onPressed: () async {
              await savePrefs(prefs.copyWith(audioDelayMs: value));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
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
              // Seed focus on the current choice so the dialog is operable by
              // remote the moment it opens.
              autofocus: code == current,
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
              style: TextStyle(color: AppColors.textSecondary),
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
          // Both directions exist on every device, but the one that matches
          // what you are holding comes first — a TV is nearly always the
          // device being set up, and a phone the one doing the setting up.
          if (isTelevisionOf(ref)) ...[
            ListTile(
              leading: const Icon(Icons.phonelink_ring),
              title: const Text('Pair with your phone'),
              subtitle: Text(
                'Copy your playlists and sync settings across, without typing',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pair/receive'),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.tv),
              title: const Text('Set up a TV'),
              subtitle: Text(
                'Send your playlists and sync settings to another device',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pair/send'),
            ),
            ListTile(
              leading: const Icon(Icons.phonelink_ring),
              title: const Text('Pair with another device'),
              subtitle: Text(
                'Receive playlists and sync settings from a set-up device',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pair/receive'),
            ),
          ],
          // Sideloaded: nothing else tells anyone a newer build exists. Absent
          // when this build is current, or when GitHub could not be reached.
          if (ref.watch(availableUpdateProvider).value case final update?)
            ListTile(
              leading: Icon(Icons.system_update_alt, color: AppColors.accent),
              title: Text('Update available — build ${update.build}'),
              subtitle: Text(
                isTelevisionOf(ref)
                    ? 'Shows where to get it'
                    : 'Download the new build',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openUpdate(context, ref, update),
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
              style: TextStyle(color: AppColors.textSecondary),
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
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/languages'),
          ),
          // Hiding groups is the blunt instrument that makes a 200-category
          // line usable, so it sits right next to the language filter that
          // does a coarser version of the same job.
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Live TV groups'),
            subtitle: Text('Hide, rename and reorder',
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/groups/live'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Movie groups'),
            subtitle: Text('Hide, rename and reorder',
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/groups/vod'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Series groups'),
            subtitle: Text('Hide, rename and reorder',
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/groups/series'),
          ),
          // The way back from hiding a channel, which happens from a menu on
          // the channel itself — without this the action would be one-way.
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hidden channels'),
            subtitle: Text('Bring individual channels back',
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/hidden-channels'),
          ),
          // Groups are made from the Live tab's channel menu; this is where
          // they are renamed, emptied and deleted.
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Channel groups'),
            subtitle: Text('Your own groups of channels, across categories',
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/custom-groups'),
          ),
          if (ReminderService.isSupported)
            ListTile(
              leading: const Icon(Icons.notifications_none_outlined),
              title: const Text('Reminders'),
              subtitle: Text('Programmes you asked to be told about',
                  style: TextStyle(color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/reminders'),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.high_quality_outlined),
            title: const Text('Group channel qualities'),
            subtitle: Text(
                'Show one row per channel and play the best of its '
                'SD/HD/FHD/4K streams',
                style: TextStyle(color: AppColors.textSecondary)),
            value: prefs.groupChannelVariants,
            activeThumbColor: AppColors.accent,
            onChanged: (v) =>
                savePrefs(prefs.copyWith(groupChannelVariants: v)),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Discovery rails'),
            subtitle: Text(
              prefs.tmdbApiKey == null
                  ? 'Award winners only — add a TMDB key for Trending & Popular'
                  : 'On — trending, popular and new in '
                      '${prefs.discoveryRegion ?? 'your region'}',
              style: TextStyle(color: AppColors.textSecondary),
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
                style: TextStyle(color: AppColors.accentAlt)),
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
                style: TextStyle(color: AppColors.accentAlt)),
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
            subtitle: Text('Keep playing when the app is minimised',
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
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Force refresh'),
            subtitle: Text('Refetch the full catalog from the source',
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
            subtitle: Text('Progress and favorites are kept',
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
                        // Focus the safe choice, so an immediate OK on a remote
                        // cancels rather than clears.
                        autofocus: true,
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
          ListTile(
            leading: Icon(switch (prefs.themeMode) {
              AppThemeMode.dark => Icons.dark_mode_outlined,
              AppThemeMode.light => Icons.light_mode_outlined,
              AppThemeMode.system => Icons.brightness_auto_outlined,
            }),
            title: const Text('Theme'),
            subtitle: Text(
              switch (prefs.themeMode) {
                AppThemeMode.dark => 'Dark — the cinematic default',
                AppThemeMode.light => 'Light',
                AppThemeMode.system => 'Follow the device',
              },
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<AppThemeMode>(
                context: context,
                builder: (context) => SimpleDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Theme'),
                  children: [
                    for (final mode in AppThemeMode.values)
                      RadioListTile<AppThemeMode>(
                        autofocus: mode == prefs.themeMode,
                        value: mode,
                        // ignore: deprecated_member_use
                        groupValue: prefs.themeMode,
                        // ignore: deprecated_member_use
                        onChanged: (_) => Navigator.pop(context, mode),
                        activeColor: AppColors.accent,
                        title: Text(switch (mode) {
                          AppThemeMode.dark => 'Dark',
                          AppThemeMode.light => 'Light',
                          AppThemeMode.system => 'Follow the device',
                        }),
                      ),
                  ],
                ),
              );
              if (picked == null) return;
              await savePrefs(prefs.copyWith(themeMode: picked));
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Size'),
            subtitle: Text(
              // Named rather than a percentage: "Large" is a choice, "115%" is
              // a number to reason about.
              '${UiSize.nearest(prefs.uiScale).label} — text and posters',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final current = UiSize.nearest(prefs.uiScale);
              final picked = await showDialog<UiSize>(
                context: context,
                builder: (context) => SimpleDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Size'),
                  children: [
                    for (final size in UiSize.values)
                      RadioListTile<UiSize>(
                        autofocus: size == current,
                        value: size,
                        // ignore: deprecated_member_use
                        groupValue: current,
                        // ignore: deprecated_member_use
                        onChanged: (_) => Navigator.pop(context, size),
                        activeColor: AppColors.accent,
                        title: Text(size.label),
                      ),
                  ],
                ),
              );
              if (picked == null) return;
              await savePrefs(prefs.copyWith(uiScale: picked.scale));
            },
          ),
          ListTile(
            leading: const Icon(Icons.speaker_notes_outlined),
            title: const Text('Audio sync'),
            subtitle: Text(
              prefs.audioDelayMs == 0
                  ? 'Automatic — adjust if sound runs ahead of the picture'
                  : 'Sound delayed ${prefs.audioDelayMs} ms on this screen',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editAudioDelay(context, prefs, savePrefs),
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
            applicationName: 'Dawn Player',
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
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600)),
    );
  }
}
