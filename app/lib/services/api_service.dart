import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    print('BTF_LOG: Initializing ApiService with baseUrl: "$apiBaseUrl"');
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('BTF_LOG: REQUEST [${options.method}] ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('BTF_LOG: RESPONSE [${response.statusCode}] ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (err, handler) {
        print('BTF_LOG: ERROR [${err.response?.statusCode}] ${err.requestOptions.uri}');
        print('BTF_LOG: ERROR DETAIL: ${err.message}');
        return handler.next(err);
      },
    ));
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Auth
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('auth/register', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> login() async {
    final response = await _dio.post('auth/login');
    return response.data;
  }

  // Games
  Future<Map<String, dynamic>> listGames({
    double? lat,
    double? lng,
    double radiusKm = 10.0,
    int? skillLevel,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _dio.get('games/', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'radius_km': radiusKm,
      if (skillLevel != null) 'skill_level': skillLevel,
      'page': page,
      'per_page': perPage,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createGame(Map<String, dynamic> data) async {
    final response = await _dio.post('games/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getGame(String id) async {
    final response = await _dio.get('games/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> updateGame(
      String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('games/$id', data: data);
    return response.data;
  }

  Future<void> deleteGame(String id) async {
    await _dio.delete('games/$id');
  }

  // Bookings
  Future<Map<String, dynamic>> createBooking(String gameId) async {
    final response = await _dio.post('games/$gameId/bookings');
    return response.data;
  }

  Future<void> cancelBooking(String bookingId) async {
    await _dio.delete('bookings/$bookingId');
  }

  Future<Map<String, dynamic>> getMyBooking(String gameId) async {
    final response = await _dio.get('games/$gameId/booking');
    return response.data;
  }


  // Venues
  Future<List<dynamic>> listVenues({String? city}) async {
    final response = await _dio.get('venues/', queryParameters: {
      if (city != null) 'city': city,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createVenue(Map<String, dynamic> data) async {
    final response = await _dio.post('venues/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getVenue(String id) async {
    final response = await _dio.get('venues/$id');
    return response.data;
  }

  // Users
  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('users/me');
    return response.data;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final response = await _dio.patch('users/me', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getUserGames(String userId) async {
    final response = await _dio.get('users/$userId/games');
    return response.data;
  }
}
