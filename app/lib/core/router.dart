import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/games/game_detail_screen.dart';
import '../screens/games/games_list_screen.dart';
import '../screens/organiser/create_game_screen.dart';
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
  ],
);
