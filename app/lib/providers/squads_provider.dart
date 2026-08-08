import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/squad.dart';
import '../services/api_service.dart';
import 'user_provider.dart';

/// The squads the signed-in user organises.
class SquadsNotifier extends AsyncNotifier<List<Squad>> {
  @override
  Future<List<Squad>> build() async {
    // Squads are organiser-scoped, so there is nothing to fetch until we know
    // who is signed in.
    final user = ref.watch(userProvider).value;
    if (user == null) return [];

    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.listSquads();
    return response
        .map((e) => Squad.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<Squad> createSquad(String name) async {
    final apiService = ref.read(apiServiceProvider);
    final created = await apiService.createSquad(name);
    await refresh();
    return Squad.fromJson(created);
  }

  Future<void> deleteSquad(String squadId) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.deleteSquad(squadId);
      return build();
    });
  }
}

final squadsProvider =
    AsyncNotifierProvider<SquadsNotifier, List<Squad>>(SquadsNotifier.new);

/// A single squad including its members.
class SquadDetailNotifier extends FamilyAsyncNotifier<Squad?, String> {
  @override
  Future<Squad?> build(String arg) async {
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.getSquad(arg);
    return Squad.fromJson(response);
  }

  Future<void> addMember({
    required String displayName,
    String? email,
    String? phone,
  }) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.addSquadMember(
        arg,
        displayName: displayName,
        email: email,
        phone: phone,
      );
      // The squad list shows member counts, so it goes stale too.
      ref.invalidate(squadsProvider);
      return build(arg);
    });
  }

  Future<void> removeMember(String memberId) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.removeSquadMember(arg, memberId);
      ref.invalidate(squadsProvider);
      return build(arg);
    });
  }

  Future<void> rename(String name) async {
    final apiService = ref.read(apiServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await apiService.renameSquad(arg, name);
      ref.invalidate(squadsProvider);
      return build(arg);
    });
  }
}

final squadDetailProvider =
    AsyncNotifierProvider.family<SquadDetailNotifier, Squad?, String>(
        SquadDetailNotifier.new);
