import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StationLocalCache Isolation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadStations returns strictly empty list when cache is empty (no fake/seed fallback)', () async {
      final cache = StationLocalCache();
      final stations = await cache.loadStations();

      expect(stations, isEmpty);
    });

    test('getCachedStations returns strictly empty list when cache is empty', () async {
      final cache = StationLocalCache();
      final stations = await cache.getCachedStations();

      expect(stations, isEmpty);
    });

    test('saveStations genuinely persists stations and loadStations retrieves them', () async {
      final cache = StationLocalCache();
      const testStation = ChargingStation(
        id: 'test-cache-id-1',
        name: 'Genuinely Discovered OSM Station',
        operatorName: 'OpenStreetMap Live',
        address: 'Jalan Sultan Ismail, Kuala Lumpur',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan Kuala Lumpur',
        latitude: 3.1550,
        longitude: 101.7080,
        maxPowerKw: 60.0,
        source: 'osm_live',
        isVerified: true,
      );

      await cache.saveStations([testStation]);

      final retrieved = await cache.loadStations();
      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('test-cache-id-1'));
      expect(retrieved.first.name, equals('Genuinely Discovered OSM Station'));
      expect(retrieved.first.source, equals('osm_live'));
    });
  });
}
