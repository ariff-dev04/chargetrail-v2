import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/user_model.dart';

/// Repository coordinating remote FastAPI authentication and local offline session cache.
class AuthRepository {
  static const String _tokenKey = 'chargetrail_auth_token_v1';
  static const String _userKey = 'chargetrail_auth_user_v1';

  final Dio _dio;
  final SharedPreferences? prefs;

  AuthRepository({
    Dio? dio,
    this.prefs,
    String? baseUrl,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
              ),
            );

  /// Load persisted user session and token from SharedPreferences.
  Future<({UserProfile? user, String? token})> loadPersistedSession() async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final token = preferences.getString(_tokenKey);
      final rawUser = preferences.getString(_userKey);

      if (token != null && rawUser != null && rawUser.isNotEmpty) {
        final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
        final user = UserProfile.fromJson(decoded);
        return (user: user, token: token);
      }
    } catch (_) {
      // Fall through to unauthenticated state on parse failure
    }
    return (user: null, token: null);
  }

  /// Persist current active session credentials.
  Future<void> saveSession(UserProfile user, String token) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, token);
      await preferences.setString(_userKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  /// Erase cached credentials on logout.
  Future<void> clearSession() async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      await preferences.remove(_tokenKey);
      await preferences.remove(_userKey);
    } catch (_) {}
  }

  /// Register new user account with API or generate local demo session.
  Future<({UserProfile user, String token})> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String preferredConnector = 'CCS2',
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'preferred_connector': preferredConnector,
        },
      );

      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
        await saveSession(user, token);
        return (user: user, token: token);
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('An account with this email already exists.');
      }
    }

    // Offline / Demo Account Fallback
    final fallbackUser = UserProfile(
      id: 'local-demo-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      preferredConnector: preferredConnector,
    );
    const fallbackToken = 'local-offline-demo-token';
    await saveSession(fallbackUser, fallbackToken);
    return (user: fallbackUser, token: fallbackToken);
  }

  /// Log into existing user account with API or activate local demo session.
  Future<({UserProfile user, String token})> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
        await saveSession(user, token);
        return (user: user, token: token);
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        throw Exception('Invalid email or password credentials.');
      }
    }

    // Offline / Demo Fallback
    final demoUser = UserProfile(
      id: 'demo-driver-001',
      email: email,
      fullName: 'Malaysian EV Driver',
      preferredConnector: 'CCS2',
    );
    const demoToken = 'local-offline-demo-token';
    await saveSession(demoUser, demoToken);
    return (user: demoUser, token: demoToken);
  }

  /// Update user profile details.
  Future<UserProfile> updateProfile({
    required String token,
    String? fullName,
    String? phoneNumber,
    String? preferredConnector,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (phoneNumber != null) payload['phone_number'] = phoneNumber;
    if (preferredConnector != null) {
      payload['preferred_connector'] = preferredConnector;
    }

    try {
      final response = await _dio.patch(
        '/api/v1/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: payload,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final updated = UserProfile.fromJson(response.data as Map<String, dynamic>);
        await saveSession(updated, token);
        return updated;
      }
    } catch (_) {}

    // Fallback local update
    final current = await loadPersistedSession();
    final updated = (current.user ?? const UserProfile(id: '0', email: '', fullName: '')).copyWith(
      fullName: fullName,
      phoneNumber: phoneNumber,
      preferredConnector: preferredConnector,
    );
    await saveSession(updated, token);
    return updated;
  }

  /// Toggle station bookmark status.
  Future<({bool isSaved, List<String> savedIds})> toggleBookmark({
    required String token,
    required String stationId,
    required UserProfile currentUser,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/users/me/bookmarks/$stationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final isSaved = data['is_saved'] as bool;
        final rawIds = data['saved_station_ids'] as List<dynamic>? ?? [];
        final ids = rawIds.map((e) => e.toString()).toList();
        final updatedUser = currentUser.copyWith(savedStationIds: ids);
        await saveSession(updatedUser, token);
        return (isSaved: isSaved, savedIds: ids);
      }
    } catch (_) {}

    // Fallback local bookmark toggling
    final currentIds = List<String>.from(currentUser.savedStationIds);
    final isSaved = !currentIds.contains(stationId);
    if (isSaved) {
      currentIds.add(stationId);
    } else {
      currentIds.remove(stationId);
    }
    final updatedUser = currentUser.copyWith(savedStationIds: currentIds);
    await saveSession(updatedUser, token);
    return (isSaved: isSaved, savedIds: currentIds);
  }
}
