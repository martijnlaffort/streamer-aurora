import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/sync/sync_providers.dart';
import 'features/home/home_providers.dart';

class AuroraApp extends ConsumerStatefulWidget {
  const AuroraApp({super.key});

  @override
  ConsumerState<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends ConsumerState<AuroraApp> {
  @override
  void initState() {
    super.initState();
    // Reconcile with the sync backend once on launch (no-op when sync is off).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await runSync(ref);
      if (result != null && result.ok && mounted) {
        ref.invalidate(homeDataProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aurora',
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
