import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/venue.dart';
import '../services/api_service.dart';

/// Dublin venues for the organiser pickers.
///
/// Falls back to the pre-seeded venue list when the API is unreachable, so
/// creating a game or a series still works offline or against a fresh database.
final venuesProvider = FutureProvider.autoDispose<List<Venue>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final List<dynamic> jsonList = await apiService.listVenues(city: 'Dublin');
    final List<Venue> list = jsonList.map((e) => Venue.fromJson(e as Map<String, dynamic>)).toList();
    if (list.isEmpty) {
      throw Exception('No venues found in database');
    }
    return list;
  } catch (_) {
    // Return pre-seeded fallbacks if offline or db not ready
    return const [
      Venue(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Irishtown Stadium (4G)',
        address: 'Ringsend, Dublin 4',
        city: 'Dublin',
        lat: 53.3412,
        lng: -6.2201,
        surface: '4G Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Sandymount YMCA',
        address: 'Sandymount Road, Dublin 4',
        city: 'Dublin',
        lat: 53.3321,
        lng: -6.2185,
        surface: '3G Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Herbert Park Pitch',
        address: 'Herbert Park, Ballsbridge',
        city: 'Dublin',
        lat: 53.3256,
        lng: -6.2341,
        surface: 'All-Weather Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000004',
        name: 'Ringsend Park Pitch',
        address: 'Ringsend Park, Dublin 4',
        city: 'Dublin',
        lat: 53.3401,
        lng: -6.2112,
        surface: '4G Astro',
      ),
    ];
  }
});
