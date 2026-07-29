import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/mappers.dart';
import 'sync_backend.dart';

/// Global playback preferences (PRD §8.10, §8.12), single-row, local-first
/// with a sync seam (PRD §9).
class PreferencesRepository {
  PreferencesRepository({
    required this._db,
    // Accepted but unused until the Phase 2 backend exists.
    // ignore: avoid_unused_constructor_parameters
    PreferencesSyncBackend? backend,
  });

  final AppDatabase _db;

  static const int singletonId = 1;

  Future<Preferences> get() async {
    final row = await (_db.preferencesTable.select()
          ..where((t) => t.id.equals(singletonId)))
        .getSingleOrNull();
    return row?.toModel() ?? const Preferences.defaults();
  }

  Future<void> save(Preferences preferences) async {
    await _db.preferencesTable.insertOnConflictUpdate(
      PreferencesTableCompanion(
        id: const Value(singletonId),
        preferredAudioLang: Value(preferences.preferredAudioLang),
        preferredSubtitleLang: Value(preferences.preferredSubtitleLang),
        autoplayNext: Value(preferences.autoplayNext),
        backgroundPlayback: Value(preferences.backgroundPlayback),
        contentLanguages: Value(
          (preferences.contentLanguages == null ||
                  preferences.contentLanguages!.isEmpty)
              ? null
              : preferences.contentLanguages!.join(','),
        ),
      ),
    );
  }
}
