import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/sync/sync_providers.dart';
import 'features/home/home_providers.dart';

class DawnPlayerApp extends ConsumerStatefulWidget {
  const DawnPlayerApp({super.key});

  @override
  ConsumerState<DawnPlayerApp> createState() => _DawnPlayerAppState();
}

class _DawnPlayerAppState extends ConsumerState<DawnPlayerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reconcile with the sync backend once on launch (no-op when sync is off).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await runSync(ref);
      if (result != null && result.ok && mounted) {
        ref.invalidate(homeDataProvider);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// iOS warns shortly before it kills a memory-heavy app. Decoded poster
  /// bitmaps are the biggest reclaimable block — dropping them here is the
  /// difference between a brief stutter and the app disappearing.
  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
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
