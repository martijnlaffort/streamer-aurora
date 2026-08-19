import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A nudge that something changed locally and should be synced soon.
///
/// Deliberately dumb and dependency-free. Repositories call [ping] after a
/// mutation (progress saved, a favourite toggled); the app-level coordinator
/// listens and debounces a real sync. This lets the data layer ask for a sync
/// without depending on the sync layer — which depends on the data layer — and
/// keeps "sync happens automatically" out of every call site.
class SyncTrigger extends ChangeNotifier {
  void ping() => notifyListeners();
}

final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  final trigger = SyncTrigger();
  ref.onDispose(trigger.dispose);
  return trigger;
});
