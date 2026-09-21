import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart' show Account;
import '../features/home/home_providers.dart';
import '../features/live/live_providers.dart' show liveCategoriesProvider;
import '../features/movies/movies_providers.dart' show vodCategoriesProvider;
import '../features/series/series_providers.dart' show seriesCategoriesProvider;
import 'db/app_database.dart' show CatalogKind;
import 'providers.dart';
import 'sync/sync_providers.dart';

/// True while a just-selected account is downloading its first catalogue and
/// history. Screens watch it so a first load reads as "loading" rather than
/// "empty" — the difference between "your stuff is on the way" and "there is
/// nothing here". A [Notifier] so a change rebuilds the widgets watching it.
class AccountWarming extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final accountWarmingProvider =
    NotifierProvider<AccountWarming, bool>(AccountWarming.new);

/// Downloads what a newly-active account needs to fill Home and the browse
/// tabs, in the background, the moment it becomes active — instead of waiting
/// for the user to open each tab.
///
/// A freshly paired or first-time account has NOTHING cached on this device, so
/// without this Home, Movies, Series and Live all sit empty until the user
/// happens to open each one and triggers its first fetch. Kicking the fetches
/// off on the switch means the content is usually already there by the time the
/// user looks, and the warming flag lets the screens say so meanwhile.
///
/// Best-effort and idempotent: every slice fetch is TTL-gated and de-duplicated
/// inside the repository, so warming an account whose cache is already fresh
/// costs nothing and returns almost immediately. Failures (offline, a panel
/// that is down) are swallowed — a warm that could not run just leaves the
/// screens to fetch on demand as before.
Future<void> warmAccount(WidgetRef ref, Account account) async {
  final warming = ref.read(accountWarmingProvider.notifier);
  warming.set(true);
  try {
    final catalog = ref.read(catalogRepositoryProvider);
    // Bootstrap the three browse slices so their tabs render the instant they
    // are opened. Independent of one another, so run them together; the
    // repository serializes the actual downloads to keep peak memory flat.
    await Future.wait(
      [
        catalog.prepareSlice(account, CatalogKind.vod),
        catalog.prepareSlice(account, CatalogKind.series),
        catalog.prepareSlice(account, CatalogKind.live),
      ].map((f) => f.catchError((Object _) {})),
    );
    ref.invalidate(vodCategoriesProvider);
    ref.invalidate(seriesCategoriesProvider);
    ref.invalidate(liveCategoriesProvider);
    // Pull watch history and My List from the sync backend and resolve their
    // titles against the catalogue, so Continue Watching and My List fill in
    // on their own. runSync does the hydration; a failure here is non-fatal.
    try {
      await runSync(ref);
    } on Object {
      // Offline or backend down — the slices we just warmed still stand.
    }
    ref.invalidate(homeDataProvider);
    ref.invalidate(myListProvider);
    ref.invalidate(discoveryRailsProvider);
  } finally {
    warming.set(false);
  }
}
