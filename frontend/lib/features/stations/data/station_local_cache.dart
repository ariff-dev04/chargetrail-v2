import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/station_model.dart';

/// Local offline cache storing charging stations in SharedPreferences.
class StationLocalCache {
  static const String _cacheKey = 'cached_stations_v3_pure_osm';

  final SharedPreferences? _prefs;

  StationLocalCache([this._prefs]);

  /// Asynchronously retrieve cached stations or return empty list (no synthetic defaults).
  Future<List<ChargingStation>> getCachedStations() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        final stations = decoded
            .map((item) => ChargingStation.fromJson(item as Map<String, dynamic>))
            .toList();
        return stations;
      }
    } catch (_) {}
    return const [];
  }

  /// Loads cached stations from SharedPreferences. Strictly returns empty list if no stations were cached.
  Future<List<ChargingStation>> loadStations() => getCachedStations();

  /// Persist retrieved stations to local storage for subsequent offline launches.
  Future<void> saveStations(List<ChargingStation> stations) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final payload = jsonEncode(stations.map((s) => s.toJson()).toList());
      await prefs.setString(_cacheKey, payload);
    } catch (_) {}
  }

  /// Clear all cached stations from local storage.
  Future<void> clearCache() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}
