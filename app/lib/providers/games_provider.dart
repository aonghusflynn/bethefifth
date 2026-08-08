import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import 'user_provider.dart';

class GamesNotifier extends AsyncNotifier<List<Game>> {
  @override
  Future<List<Game>> build() async {
    final apiService = ref.read(apiServiceProvider);
    
    // For Dublin MVP, default to Dublin center coordinates
    const double dublinLat = 53.349805;
    const double dublinLng = -6.260310;
    
    try {
      final response = await apiService.listGames(
        lat: dublinLat,
        lng: dublinLng,
        radiusKm: 25.0,
      );
      final List<dynamic> gamesList = response['items'] as List<dynamic>? ?? [];
      return gamesList.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> createGame({
    required String title,
    required String venueId,
    required DateTime startsAt,
    required int durationMinutes,
    required int maxPlayers,
    required int skillLevel,
    String? description,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final payload = {
        'venue_id': venueId,
        'title': title,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'max_players': maxPlayers,
        'skill_level': skillLevel,
        if (description != null) 'description': description,
      };
      await apiService.createGame(payload);
      return build();
    });
  }
}

final gamesProvider =
    AsyncNotifierProvider<GamesNotifier, List<Game>>(GamesNotifier.new);

class GameDetailNotifier extends FamilyAsyncNotifier<Game?, String> {
  @override
  Future<Game?> build(String arg) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final response = await apiService.getGame(arg);
      return Game.fromJson(response);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  Future<void> joinGame() async {
    final apiService = ref.read(apiServiceProvider);
    final gameId = arg;
    
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.createBooking(gameId);
      ref.invalidate(gamesProvider);
      ref.invalidate(myBookingProvider(gameId));
      ref.invalidate(userBookedGamesProvider);
      return build(gameId);
    });
  }

  Future<void> cancelBooking(String bookingId) async {
    final apiService = ref.read(apiServiceProvider);
    final gameId = arg;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.cancelBooking(bookingId);
      ref.invalidate(gamesProvider);
      ref.invalidate(myBookingProvider(gameId));
      ref.invalidate(userBookedGamesProvider);
      return build(gameId);
    });
  }

  /// Answer a match invitation.
  ///
  /// Accepting claims a slot first-come-first-served, falling back to the
  /// waitlist if the game filled first. Declining a slot already held releases
  /// it and promotes whoever is next in the queue.
  Future<void> respondToInvitation({required bool attending}) async {
    final apiService = ref.read(apiServiceProvider);
    final gameId = arg;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.respondToAttendance(gameId, attending: attending);
      ref.invalidate(gamesProvider);
      ref.invalidate(myBookingProvider(gameId));
      ref.invalidate(userBookedGamesProvider);
      return build(gameId);
    });
  }

  /// Invite a squad to this game. Invitations claim no slots.
  Future<int> inviteSquad(String squadId) async {
    final apiService = ref.read(apiServiceProvider);
    final invited = await apiService.inviteSquadToGame(arg, squadId: squadId);
    ref.invalidate(myBookingProvider(arg));
    state = await AsyncValue.guard(() => build(arg));
    return invited.length;
  }

  /// Open this game to the marketplace, or take it back off.
  ///
  /// Closing fails with a 409 once an outside player has claimed a slot; the
  /// caller surfaces that to the organiser.
  Future<void> setMarketplaceOpen(bool open) async {
    final apiService = ref.read(apiServiceProvider);
    final gameId = arg;

    if (open) {
      await apiService.openToMarketplace(gameId);
    } else {
      await apiService.closeToMarketplace(gameId);
    }
    ref.invalidate(gamesProvider);
    state = await AsyncValue.guard(() => build(gameId));
  }
}

final gameDetailProvider =
    AsyncNotifierProvider.family<GameDetailNotifier, Game?, String>(
        GameDetailNotifier.new);

final myBookingProvider = FutureProvider.family.autoDispose<Booking?, String>((ref, gameId) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return null;
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getMyBooking(gameId);
    return Booking.fromJson(response);
  } catch (_) {
    return null;
  }
});

