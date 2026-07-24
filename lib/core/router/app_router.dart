import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/accounts_screen.dart';
import '../../features/settings/presentation/add_account_screen.dart';
import '../../features/settings/presentation/source_probe_screen.dart';

/// Provider-wrapped from day one so later tasks can add route guards that
/// watch app state (active account, onboarding) without rewiring the app.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/accounts',
        name: 'accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/accounts/add',
        name: 'addAccount',
        builder: (context, state) => const AddAccountScreen(),
      ),
      GoRoute(
        path: '/dev/source-probe',
        name: 'sourceProbe',
        builder: (context, state) => const SourceProbeScreen(),
      ),
    ],
  );
});
