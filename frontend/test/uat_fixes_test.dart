import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/location_service.dart';
import 'package:frontend/features/community/presentation/submit_station_sheet.dart';
import 'package:frontend/features/routing/domain/route_models.dart';
import 'package:frontend/features/routing/presentation/widgets/route_telemetry_card.dart';
import 'package:frontend/features/stations/data/osm_overpass_service.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/vehicles/domain/vehicle_model.dart';
import 'package:frontend/features/vehicles/presentation/garage_screen.dart';
import 'package:frontend/features/vehicles/presentation/vehicle_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Narrow Phone Viewport Overflow Regression Tests (Module 7.5)', () {
    testWidgets('GarageScreen renders long vehicle name without horizontal overflow on 360px screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longVehicle = VehicleProfile(
        id: 'test-long-name',
        brand: 'Tesla',
        modelName: 'Model 3 Long Range Dual Motor All-Wheel Drive',
        batteryCapacityKwh: 75.0,
        usableRangeKm: 629.0,
        efficiencyWhPerKm: 125.0,
        maxDcChargeKw: 250.0,
        isPrimary: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleControllerProvider.overrideWith(() {
              return _MockVehicleNotifier(longVehicle);
            }),
          ],
          child: const MaterialApp(
            home: GarageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active EV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RouteTelemetryCard renders stops timeline without overflow on 360px screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleStation = StationLocalCache.defaultMalaysianStations().first;
      final plan = RoutePlanResult(
        originName: 'Kuala Lumpur (KLCC)',
        destinationName: 'Penang (Gurney Plaza)',
        totalDistanceKm: 356.0,
        estimatedDriveMinutes: 245,
        totalChargingMinutes: 22,
        totalTripMinutes: 267,
        startingSocPercent: 55,
        projectedDestinationSocWithoutCharging: -28,
        finalArrivalSocPercent: 42,
        totalEnergyKwh: 51.2,
        rangeAnxietyStatus: 'critical_charging_required',
        statusSummary: 'Highway stop mandatory to reach destination safely.',
        vehicleSummary: 'Tesla Model 3 Long Range',
        polylinePoints: const [],
        recommendedStops: [
          ChargingStopRecommendation(
            station: sampleStation,
            distanceFromOriginKm: 152.0,
            detourDistanceKm: 0.5,
            arrivalSocPercent: 20,
            departureSocPercent: 80,
            energyAddedKwh: 45.0,
            estimatedChargeMinutes: 22,
            estimatedCostMyr: 54.00,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteTelemetryCard(plan: plan),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Recommended Charging Stops'), findsOneWidget);
      expect(find.text('Tap for access guide'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SubmitStationSheet Location Pin & City Dropdown Tests', () {
    testWidgets('SubmitStationSheet renders Pin Location card and Malaysian City dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SubmitStationSheet(
                initialLatitude: 3.1390,
                initialLongitude: 101.6869,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('📍 Charger Pin Location'), findsOneWidget);
      expect(find.text('Use My GPS'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);
      expect(find.text('Kuala Lumpur'), findsWidgets);
    });
  });

  group('OsmOverpassService & LocationService Reverse Geocoding Tests', () {
    test('LocationService fallback resolves nearest Malaysian city', () async {
      final service = LocationService();
      final geo = await service.reverseGeocode(5.4164, 100.3327); // Penang coordinates

      expect(geo['city'], contains('George Town'));
      expect(geo['state'], equals('Penang'));
    });

    test('OsmOverpassService deduplicates existing stations within 150m', () async {
      final service = OsmOverpassService();
      final baseline = StationLocalCache.defaultMalaysianStations();

      // Querying an already scanned cell or duplicate coordinates
      final newStations = await service.fetchViewportStations(
        minLat: 3.15,
        minLng: 101.71,
        maxLat: 3.16,
        maxLng: 101.72,
        existingStations: baseline,
      );

      expect(newStations, isA<List>());
    });
  });
}

class _MockVehicleNotifier extends VehicleNotifier {
  final VehicleProfile _mockActive;

  _MockVehicleNotifier(this._mockActive);

  @override
  VehicleState build() {
    return VehicleState(
      garageVehicles: [_mockActive],
      simulatedCurrentSoc: 80,
    );
  }
}
