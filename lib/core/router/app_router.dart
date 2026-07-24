import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/movies/presentation/movie_detail_screen.dart';
import '../../features/movies/presentation/movies_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/series/presentation/series_detail_screen.dart';
import '../../features/series/presentation/series_screen.dart';
import '../../features/settings/presentation/accounts_screen.dart';
import '../../features/settings/presentation/add_account_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/source_probe_screen.dart';
import 'app_shell.dart';

/// Provider-wrapped so later tasks can add guards that watch app state.
/// Tab branches live in a StatefulShellRoute; detail and account flows are
/// root-level routes that cover the shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/movies',
                name: 'movies',
                builder: (context, state) => const MoviesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/series',
                name: 'series',
                builder: (context, state) => const SeriesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/movie/:id',
        name: 'movieDetail',
        builder: (context, state) =>
            MovieDetailScreen(movieId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/series/:id',
        name: 'seriesDetail',
        builder: (context, state) =>
            SeriesDetailScreen(seriesId: state.pathParameters['id']!),
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
