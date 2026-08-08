import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class UserNotifier extends AsyncNotifier<BtfUser?> {
  @override
  Future<BtfUser?> build() async {
    final authState = ref.watch(authStateProvider);
    final apiService = ref.read(apiServiceProvider);

    return authState.when(
      data: (firebaseUser) async {
        if (firebaseUser == null) {
          apiService.clearAuthToken();
          return null;
        }

        // Fetch ID token from Firebase
        final token = await firebaseUser.getIdToken();
        if (token != null) {
          apiService.setAuthToken(token);
        } else {
          // If we can't get a token, use mock local token in dev
          apiService.setAuthToken('mock-token-${firebaseUser.uid}');
        }

        try {
          final userJson = await apiService.getMe();
          return BtfUser.fromJson(userJson);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            // Auto-registration handshake
            try {
              final registrationData = {
                'email': firebaseUser.email,
                'display_name': firebaseUser.displayName ?? 'Player',
                'photo_url': firebaseUser.photoURL,
              };
              await apiService.register(registrationData);
              final userJson = await apiService.getMe();
              return BtfUser.fromJson(userJson);
            } catch (err) {
              state = AsyncValue.error(err, StackTrace.current);
              return null;
            }
          }
          state = AsyncValue.error(e, StackTrace.current);
          return null;
        }
      },
      loading: () => null,
      error: (err, stack) {
        state = AsyncValue.error(err, stack);
        return null;
      },
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Directly injects a fetched user into state without going through
  /// [build]'s Firebase `authStateChanges` gate. Needed for the dev
  /// mock-bypass login: it authenticates by setting a raw token on
  /// [ApiService] rather than signing in through Firebase, so
  /// `authStateProvider` never emits and a normal [build]/invalidate would
  /// leave this provider stuck on `null` forever.
  void setMockUser(BtfUser user) {
    state = AsyncValue.data(user);
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? position,
    int? skillLevel,
    String? locale,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updateData = {
        if (displayName != null) 'display_name': displayName,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (position != null) 'position': position,
        if (skillLevel != null) 'skill_level': skillLevel,
        if (locale != null) 'locale': locale,
      };
      final userJson = await apiService.updateMe(updateData);
      return BtfUser.fromJson(userJson);
    });
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
  }
}

final userProvider =
    AsyncNotifierProvider<UserNotifier, BtfUser?>(UserNotifier.new);

final userBookedGamesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getUserGames(user.id);
    final List<dynamic> items = response['items'] as List<dynamic>? ?? [];
    return items.map((e) => e['id'] as String).toList();
  } catch (_) {
    return [];
  }
});
