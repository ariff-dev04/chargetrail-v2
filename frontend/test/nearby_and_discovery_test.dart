import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/stations/data/malaysia_ev_registry.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:frontend/features/stations/presentation/station_controller.dart';
import 'package:frontend/features/stations/presentation/widgets/nearby_stations_carousel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MalaysiaEvRegistry Open Data Tests (Module 7.6)', () {
    test('Registry contains 32 open-data EV stations across Malaysia', () {
      final all = MalaysiaEvRegistry.getAllStations();
      expect(all.length, equals(32));

      for (final s in all) {
        expect(s.source, equals('open_data_my'));
        expect(s.isVerified, isFalse);
        expect(s.latitude, inInclusiveRange(1.0, 7.0));
        expect(s.longitude, inInclusiveRange(99.0, 118.0));
        expect(s.maxPowerKw, greaterThanOrEqualTo(50.0));
      }
    });

    test('getStationsNear returns stations filtered by radial distance', () {
      // Query near central KL (KLCC / Bangsar)
      final klStations = MalaysiaEvRegistry.getStationsNear(3.1432, 101.6671, radiusKm: 15.0);
      expect(klStations.length, greaterThanOrEqualTo(5));
      final names = klStations.map((s) => s.name).toList();
      expect(names, contains('Bangsar Shopping Centre JomCharge'));

      // Query near Penang (George Town)
      final penangStations = MalaysiaEvRegistry.getStationsNear(5.3332, 100.3065, radiusKm: 30.0);
      expect(penangStations.length, greaterThanOrEqualTo(1));
      expect(penangStations.any((s) => s.name.contains('Queensbay') || s.name.contains('Design Village')), isTrue);
    });
  });

  group('StationState nearbyStations Sorting Tests (Module 7.6)', () {
    test('nearbyStations getter sorts stations by ascending distance', () {
      final stations = StationLocalCache.defaultMalaysianStations();

      // Reference point: KLCC (3.1578, 101.7118)
      final state = StationState(
        allStations: stations,
        filteredStations: stations,
        referenceLat: 3.1578,
        referenceLng: 101.7118,
      );

      final sorted = state.nearbyStations;
      expect(sorted.length, equals(stations.length));

      // Closest station to KLCC should be Suria KLCC
      expect(sorted.first.name, contains('Suria KLCC'));
      expect(state.distanceKmTo(sorted.first.latitude, sorted.first.longitude), closeTo(0.0, 0.1));

      // Farthest station from KLCC should be in Johor Bahru or Penang
      final last = sorted.last;
      expect(
        last.city.contains('Johor Bahru') || last.city.contains('George Town'),
        isTrue,
      );
      expect(state.distanceKmTo(last.latitude, last.longitude), greaterThan(250.0));
    });
  });

  group('NearbyStationsCarousel Widget Tests (Module 7.6)', () {
    testWidgets('Renders nearby carousel cards with distance and handles tap', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stations = StationLocalCache.defaultMalaysianStations();
      ChargingStation? tappedStation;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: NearbyStationsCarousel(
                stations: stations,
                distanceCalculator: (lat, lng) => 1.2,
                onStationTap: (s) {
                  tappedStation = s;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('📍 Nearby Chargers'), findsOneWidget);
      expect(find.text('View List'), findsOneWidget);
      expect(find.text('1.2 km'), findsWidgets);

      // Tap first carousel card
      await tester.tap(find.text('1.2 km').first);
      await tester.pump();

      expect(tappedStation, isNotNull);
      expect(tappedStation!.name, equals(stations.first.name));
    });
  });
}
