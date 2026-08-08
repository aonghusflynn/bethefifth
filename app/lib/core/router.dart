import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/games/game_detail_screen.dart';
import '../screens/games/games_list_screen.dart';
import '../screens/organiser/create_game_screen.dart';
import '../screens/organiser/create_series_screen.dart';
import '../screens/organiser/series_list_screen.dart';
import '../screens/organiser/squad_detail_screen.dart';
import '../screens/organiser/squads_list_screen.dart';
import '../screens/profile/profile_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) => '/games',
    ),
    GoRoute(
      path: '/games',
      builder: (context, state) => const GamesListScreen(),
    ),
    GoRoute(
      path: '/games/:id',
      builder: (context, state) => GameDetailScreen(
        gameId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/organiser/create-game',
      builder: (context, state) => const CreateGameScreen(),
    ),
    GoRoute(
      path: '/organiser/squads',
      builder: (context, state) => const SquadsListScreen(),
    ),
    GoRoute(
      path: '/organiser/squads/:id',
      builder: (context, state) => SquadDetailScreen(
        squadId: state.pathParameters['id']!,
      ),
    ),
    // Declared before '/organiser/series/:id' would be, so that the literal
    // 'create' segment can never be read as a series id.
    GoRoute(
      path: '/organiser/series/create',
      builder: (context, state) => const CreateSeriesScreen(),
    ),
    GoRoute(
      path: '/organiser/series',
      builder: (context, state) => const SeriesListScreen(),
    ),
  ],
);
