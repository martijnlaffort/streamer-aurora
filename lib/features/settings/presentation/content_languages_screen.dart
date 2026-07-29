import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Content-language picker (PRD §8.3). IPTV panels tag language on the
/// category, so this lets the user keep only the languages they want — the
/// list is auto-detected from their own catalog. All-on (the default) means
/// no filtering.
class ContentLanguagesScreen extends ConsumerWidget {
  const ContentLanguagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableContentLanguagesProvider);
    final prefs =
        ref.watch(preferencesProvider).value ?? const Preferences.defaults();

    bool isOn(String code) =>
        prefs.contentLanguages == null ||
        prefs.contentLanguages!.contains(code);

    Future<void> toggle(List<String> allCodes, String code, bool on) async {
      final current = <String>{for (final c in allCodes) if (isOn(c)) c};
      if (on) {
        current.add(code);
      } else {
        current.remove(code);
      }
      // Everything on → store null so future new languages stay visible too.
      final save = current.length >= allCodes.length ? null : current.toList();
      await ref.read(preferencesRepositoryProvider).save(Preferences(
            preferredAudioLang: prefs.preferredAudioLang,
            preferredSubtitleLang: prefs.preferredSubtitleLang,
            autoplayNext: prefs.autoplayNext,
            backgroundPlayback: prefs.backgroundPlayback,
            contentLanguages: save,
          ));
      ref.invalidate(preferencesProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content languages'),
        actions: [
          if (prefs.contentLanguages != null)
            TextButton(
              onPressed: () async {
                await ref.read(preferencesRepositoryProvider).save(Preferences(
                      preferredAudioLang: prefs.preferredAudioLang,
                      preferredSubtitleLang: prefs.preferredSubtitleLang,
                      autoplayNext: prefs.autoplayNext,
                      backgroundPlayback: prefs.backgroundPlayback,
                    ));
                ref.invalidate(preferencesProvider);
              },
              child: const Text('Show all'),
            ),
        ],
      ),
      body: available.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (langs) {
          if (langs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No categories to filter yet — add an account and let the '
                  'catalog load first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          final allCodes = [for (final l in langs) l.lang.code];
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Only the languages you check appear across Movies, Series, '
                  'Live and Home. Language is detected from each category’s '
                  'name; anything unrecognised lands under “Other”.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              for (final entry in langs)
                CheckboxListTile(
                  value: isOn(entry.lang.code),
                  activeColor: AppColors.accent,
                  title: Text(entry.lang.label),
                  subtitle: Text(
                    '${entry.count} '
                    '${entry.count == 1 ? 'category' : 'categories'}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onChanged: (v) => toggle(allCodes, entry.lang.code, v ?? false),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
