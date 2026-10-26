import 'package:dio/dio.dart';
import '../domain/station_model.dart';
import 'station_local_cache.dart';

/// Repository coordinating remote FastAPI station discovery and local cache failover.
class StationRepository {
  final Dio _dio;
  final StationLocalCache _localCache;

  StationRepository({
    Dio? dio,
    StationLocalCache? localCache,
    String? baseUrl,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://localhost:8000',
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
              ),
            ),
        _localCache = localCache ?? StationLocalCache();

  /// Retrieve stations from backend API, automatically failing over to offline cache.
  Future<({List<ChargingStation> stations, bool isOffline})> fetchStations({
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
        queryParams['min_lat'] = minLat;
        queryParams['min_lng'] = minLng;
        queryParams['max_lat'] = maxLat;
        queryParams['max_lng'] = maxLng;
      }

      final response = await _dio.get(
        '/api/v1/stations',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List<dynamic>)
            .map((item) => ChargingStation.fromJson(item as Map<String, dynamic>))
            .toList();

        // Asynchronously update local cache without awaiting blocking
        _localCache.saveStations(list);

        return (stations: list, isOffline: false);
      }
    } catch (_) {
      // Network failure, connection refused, or backend offline
    }

    // Graceful offline failover
    final fallbackList = await _localCache.getCachedStations();
    return (stations: fallbackList, isOffline: true);
  }

  /// Retrieve full detail for a station by unique UUID.
  Future<ChargingStation?> fetchStationById(String stationId) async {
    try {
      final response = await _dio.get('/api/v1/stations/$stationId');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ChargingStation.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to search local offline cache
    }

    final cached = await _localCache.getCachedStations();
    try {
      return cached.firstWhere((s) => s.id == stationId);
    } catch (_) {
      return null;
    }
  }
}
