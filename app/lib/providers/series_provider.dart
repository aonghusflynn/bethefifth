import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/series.dart';
import '../services/api_service.dart';
import 'games_provider.dart';
import 'user_provider.dart';

/// The recurring fixtures the signed-in user organises.
class SeriesNotifier extends AsyncNotifier<List<GameSeries>> {
  @override
  Future<List<GameSeries>> build() async {
    final user = ref.watch(userProvider).value;
    if (user == null) return [];

    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.listSeries();
    return response
        .map((e) => GameSeries.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> createSeries({
    required String venueId,
    required String title,
    required DateTime startsAt,
    required String rrule,
    String? squadId,
    String? description,
    int durationMinutes = 60,
    int maxPlayers = 10,
    int skillLevel = 3,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.createSeries({
        'venue_id': venueId,
        'title': title,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'rrule': rrule,
        if (squadId != null) 'squad_id': squadId,
        if (description != null && description.isNotEmpty)
          'description': description,
        'duration_minutes': durationMinutes,
        'max_players': maxPlayers,
        'skill_level': skillLevel,
      });
      return build();
    });
  }

  /// Pause or resume a series.
  ///
  /// Pausing only stops future instances being created — games already
  /// scheduled are left alone, since players may have committed to them.
  Future<void> setActive(String seriesId, {required bool isActive}) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.setSeriesActive(seriesId, isActive: isActive);
      return build();
    });
  }

  Future<void> deleteSeries(String seriesId) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.deleteSeries(seriesId);
      // Deleting a series detaches its games rather than cancelling them, so
      // the games list changes shape.
      ref.invalidate(gamesProvider);
      return build();
    });
  }
}

final seriesProvider =
    AsyncNotifierProvider<SeriesNotifier, List<GameSeries>>(SeriesNotifier.new);
