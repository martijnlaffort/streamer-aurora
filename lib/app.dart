import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/sync/sync_providers.dart';
import 'data/sync/sync_trigger.dart';
import 'features/home/home_providers.dart';
import 'features/live/live_providers.dart' show favoriteChannelsProvider;
import 'features/movies/movies_providers.dart' show isFavoriteProvider;

class DawnPlayerApp extends ConsumerStatefulWidget {
  const DawnPlayerApp({super.key});

  @override
  ConsumerState<DawnPlayerApp> createState() => _DawnPlayerAppState();
}

/// Owns automatic sync. There is no "Sync now" button by design — the whole
/// point is that watching something or editing My List on any device shows up
/// on the others without the user thinking about it. Four triggers, all funnel
/// through one guarded [_sync]:
///
///  - **launch** and **resume**: pull changes made on other devices;
///  - **background**: push what changed this session before foreground is lost
///    (so stopping an episode and picking up another device Just Works);
///  - **on local change** (debounced): the responsive path — a saved position
///    or a toggled favourite reaches the server within seconds;
///  - **periodic** while foregrounded: a safety net for long sessions and for
///    changes arriving from another device mid-session.
class _DawnPlayerAppState extends ConsumerState<DawnPlayerApp>
    with WidgetsBindingObserver {
  Timer? _debounce;
  Timer? _periodic;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncTriggerProvider).addListener(_onLocalChange);
      _sync();
      _periodic = Timer.periodic(const Duration(minutes: 2), (_) => _sync());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    ref.read(syncTriggerProvider).removeListener(_onLocalChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A local write happened. The player saves a position every few seconds, so
  /// collapse a burst into one push rather than syncing on every tick.
  void _onLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), _sync);
  }

  Future<void> _sync() async {
    if (_syncing) return; // never let two syncs overlap
    _syncing = true;
    try {
      final result = await runSync(ref);
      // Only rebuild the rails when the reconcile actually changed something.
      // Doing it every cycle is what made the screen visibly refresh itself
      // every couple of minutes; a sync that found nothing new must be
      // completely invisible.
      if (result != null && result.ok && result.changedLocally && mounted) {
        ref.invalidate(homeDataProvider);
        ref.invalidate(myListProvider);
        // A favourite added or removed on another device also changes the Live
        // tab's Favourites row and every heart/My List icon, which read their
        // own providers. Invalidating the family clears all its keys.
        if (result.favoritesChanged) {
          ref.invalidate(favoriteChannelsProvider);
          ref.invalidate(isFavoriteProvider);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      _sync();
    }
  }

  /// iOS warns shortly before it kills a memory-heavy app. Decoded poster
  /// bitmaps are the biggest reclaimable block — dropping them here is the
  /// difference between a brief stutter and the app disappearing.
  @override
  void didHaveMemoryPressure() {
    // Release the decoded images we are NOT showing. That is where the bulk of
    // reclaimable memory sits after scrolling a large catalogue, and dropping it
    // is invisible to the user.
    PaintingBinding.instance.imageCache.clear();
    // Deliberately NOT clearLiveImages(). That evicts the images currently on
    // screen, so every visible poster and backdrop had to re-decode and each one
    // flashed back through its placeholder — which read as the whole app
    // reloading itself, and fired exactly when the user was scrolling or opening
    // a detail page (peak decode) but never while watching a video (no posters
    // being decoded). Posters are decode-capped at their on-screen size, so the
    // live set is small; the eviction cost far outweighed what it freed.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dawn Player',
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
