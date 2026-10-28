import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:frontend/features/stations/presentation/widgets/station_detail_sheet.dart';
import 'package:frontend/features/stations/presentation/widgets/station_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTestDiscoveryStations = [
  ChargingStation(
    id: '9ec6c0f7-48d9-48b1-ad1b-0e6a157fa1bf',
    name: 'Suria KLCC Gentari Charging Hub',
    operatorName: 'Gentari',
    address: '241, Suria KLCC, 50088 Kuala Lumpur',
    city: 'Kuala Lumpur',
    state: 'Wilayah Persekutuan Kuala Lumpur',
    latitude: 3.1578,
    longitude: 101.7118,
    plugTypes: [
      PlugInfo(type: 'CCS2', powerKw: 180.0, count: 3),
      PlugInfo(type: 'Type 2', powerKw: 22.0, count: 1),
    ],
    maxPowerKw: 180.0,
    isAvailable: true,
    is24Hours: false,
    chargingCostMyr: 1.50,
    parkingFeeMyr: 5.00,
    parkingLevel: 'Basement B1, Pillar B12',
    operationHours: '06:00 - 24:00',
    amenities: ['Dining', 'Restroom', 'Shopping', 'Surau', 'Security'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Enter via Jalan Ampang basement ramp into Carpark B1.'),
      AccessStep(stepNumber: 2, instruction: 'Follow green EV Hub floor markings toward Pillar B12.'),
    ],
    rating: 4.8,
    reviewCount: 34,
    source: 'community',
    isVerified: true,
  ),
  ChargingStation(
    id: 'd4e5f6a1-b2c3-4d4e-1f5a-6b7c8d9e0f1a',
    name: 'Mid Valley Southkey Gentari Hub',
    operatorName: 'Gentari',
    address: '1, Persiaran Southkey 1, 80150 Johor Bahru, Johor',
    city: 'Johor Bahru',
    state: 'Johor',
    latitude: 1.4989,
    longitude: 103.7774,
    plugTypes: [
      PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2),
      PlugInfo(type: 'CHAdeMO', powerKw: 50.0, count: 1),
    ],
    maxPowerKw: 120.0,
    isAvailable: true,
    is24Hours: true,
    chargingCostMyr: 1.40,
    parkingFeeMyr: 2.50,
    parkingLevel: 'South Carpark Level P2, Pillar S18',
    operationHours: '24 Hours',
    amenities: ['Dining', 'Restroom', 'Shopping'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Enter South Carpark ramp from Jalan Bakar Batu.'),
    ],
    rating: 4.8,
    reviewCount: 31,
    source: 'community',
    isVerified: true,
  ),
  ChargingStation(
    id: 'c3d4e5f6-a1b2-4c3d-0e4f-5a6b7c8d9e0f',
    name: 'TNB Electron Tapah R&R Northbound',
    operatorName: 'TNB Electron',
    address: 'PLUS Highway KM 332, Northbound',
    city: 'Tapah',
    state: 'Perak',
    latitude: 4.3138,
    longitude: 101.2582,
    plugTypes: [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 2)],
    maxPowerKw: 180.0,
    isAvailable: true,
    is24Hours: true,
    chargingCostMyr: 1.60,
    parkingFeeMyr: 0.0,
    parkingLevel: 'R&R Northbound Dedicated EV Bay',
    operationHours: '24 Hours',
    amenities: ['Dining', 'Restroom', 'Convenience Store', 'Surau', 'Petrol Station'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Exit PLUS highway at Tapah R&R Northbound rest stop.'),
    ],
    rating: 4.7,
    reviewCount: 58,
    source: 'community',
    isVerified: true,
  ),
  ChargingStation(
    id: 'b2c3d4e5-f6a1-4b2c-9d3e-4f5a6b7c8d9e',
    name: 'Sunway Pyramid chargEV Station',
    operatorName: 'chargEV',
    address: '3, Jalan PJS 11/15, Bandar Sunway, 47500 Petaling Jaya, Selangor',
    city: 'Petaling Jaya',
    state: 'Selangor',
    latitude: 3.0733,
    longitude: 101.6078,
    plugTypes: [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2)],
    maxPowerKw: 60.0,
    isAvailable: true,
    is24Hours: false,
    chargingCostMyr: 1.20,
    parkingFeeMyr: 4.00,
    parkingLevel: 'CP2 Carpark Level B1',
    operationHours: '07:00 - 23:00',
    amenities: ['Dining', 'Restroom', 'Shopping'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Enter CP2 carpark entrance opposite Sunway Resort Hotel.'),
    ],
    rating: 4.5,
    reviewCount: 20,
    source: 'community',
    isVerified: true,
  ),
  ChargingStation(
    id: 'e5f6a1b2-c3d4-4e5f-2a6b-7c8d9e0f1a2b',
    name: 'Gurney Plaza Shell Recharge',
    operatorName: 'Shell Recharge',
    address: '170, Gurney Dr, 10250 George Town, Penang',
    city: 'George Town',
    state: 'Penang',
    latitude: 5.4372,
    longitude: 100.3096,
    plugTypes: [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2)],
    maxPowerKw: 60.0,
    isAvailable: true,
    is24Hours: false,
    chargingCostMyr: 1.30,
    parkingFeeMyr: 3.00,
    parkingLevel: 'Multi-storey Carpark Level 5',
    operationHours: '10:00 - 22:00',
    amenities: ['Dining', 'Restroom', 'Shopping'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Follow multi-storey carpark spiral ramp up to Level 5.'),
    ],
    rating: 4.6,
    reviewCount: 22,
    source: 'community',
    isVerified: true,
  ),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StationLocalCache().saveStations(_kTestDiscoveryStations);
  });

  group('ChargingStation & PlugInfo Serialization Tests', () {
    test('ChargingStation parses JSON and serializes back idempotently', () {
      final sample = _kTestDiscoveryStations.first;
      final json = sample.toJson();

      final reconstructed = ChargingStation.fromJson(json);

      expect(reconstructed.id, equals(sample.id));
      expect(reconstructed.name, equals('Suria KLCC Gentari Charging Hub'));
      expect(reconstructed.operatorName, equals('Gentari'));
      expect(reconstructed.maxPowerKw, equals(180.0));
      expect(reconstructed.parkingLevel, equals('Basement B1, Pillar B12'));
      expect(reconstructed.plugTypes.length, equals(2));
      expect(reconstructed.howToAccess.length, equals(2));
      expect(reconstructed.howToAccess.first.stepNumber, equals(1));
    });
  });

  group('StationFilter Domain Filtering Tests', () {
    final stations = _kTestDiscoveryStations;
    final klcc = stations.firstWhere((s) => s.name.contains('KLCC'));
    final southkey = stations.firstWhere((s) => s.name.contains('Southkey'));
    final tapah = stations.firstWhere((s) => s.name.contains('Tapah'));

    test('Filter by connector type matches correctly', () {
      const chademoFilter = StationFilter(connectorType: 'CHAdeMO');
      expect(chademoFilter.matches(southkey), isTrue);
      expect(chademoFilter.matches(klcc), isFalse);

      const ccs2Filter = StationFilter(connectorType: 'CCS2');
      expect(ccs2Filter.matches(klcc), isTrue);
      expect(ccs2Filter.matches(southkey), isTrue);
    });

    test('Filter by minimum kW filters out low power stations', () {
      const ultraFastFilter = StationFilter(minKw: 120.0);
      expect(ultraFastFilter.matches(klcc), isTrue); // 180kW
      expect(ultraFastFilter.matches(southkey), isTrue); // 120kW

      final pyramid = stations.firstWhere((s) => s.name.contains('Pyramid'));
      expect(ultraFastFilter.matches(pyramid), isFalse); // 60kW
    });

    test('Filter by 24 hours access', () {
      const hoursFilter = StationFilter(only24Hours: true);
      expect(hoursFilter.matches(tapah), isTrue);
      expect(hoursFilter.matches(klcc), isFalse); // 06:00 - 24:00 mall
    });

    test('Filter by amenity matches sub-strings', () {
      const petrolFilter = StationFilter(amenity: 'Petrol Station');
      expect(petrolFilter.matches(tapah), isTrue);
      expect(petrolFilter.matches(klcc), isFalse);

      const diningFilter = StationFilter(amenity: 'Dining');
      expect(diningFilter.matches(klcc), isTrue);
      expect(diningFilter.matches(tapah), isTrue);
    });

    test('Filter by text search query across name and operator', () {
      const gentariFilter = StationFilter(searchQuery: 'Gentari');
      expect(gentariFilter.matches(klcc), isTrue);
      expect(gentariFilter.matches(southkey), isTrue);
      expect(gentariFilter.matches(tapah), isFalse);

      const penangFilter = StationFilter(searchQuery: 'Penang');
      final gurney = stations.firstWhere((s) => s.name.contains('Gurney'));
      expect(penangFilter.matches(gurney), isTrue);
      expect(penangFilter.matches(klcc), isFalse);
    });
  });

  group('StationFilterBar Widget Tests', () {
    testWidgets('Renders search input and triggers filter callbacks',
        (tester) async {
      String? toggledConnector;
      double? toggledKw;
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StationFilterBar(
              activeFilter: const StationFilter(),
              onSearchChanged: (_) {},
              onToggleConnector: (c) => toggledConnector = c,
              onToggleMinKw: (kw) => toggledKw = kw,
              onToggle24Hours: () {},
              onToggleAmenity: (_) {},
              onReset: () => resetCalled = true,
            ),
          ),
        ),
      );

      // Verify search input is displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('CCS2'), findsOneWidget);
      expect(find.text('120kW+ Fast'), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);

      // Tap CCS2 chip
      await tester.tap(find.text('CCS2'));
      await tester.pump();
      expect(toggledConnector, equals('CCS2'));

      // Tap 120kW+ Fast chip
      await tester.tap(find.text('120kW+ Fast'));
      await tester.pump();
      expect(toggledKw, equals(120.0));

      // Re-render with active filter to show Reset button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StationFilterBar(
              activeFilter: const StationFilter(connectorType: 'CCS2'),
              onSearchChanged: (_) {},
              onToggleConnector: (_) {},
              onToggleMinKw: (_) {},
              onToggle24Hours: () {},
              onToggleAmenity: (_) {},
              onReset: () => resetCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Reset'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(resetCalled, isTrue);
    });
  });

  group('StationDetailSheet Widget Tests', () {
    testWidgets('Displays station metadata, parking level, and access steps',
        (tester) async {
      final station = _kTestDiscoveryStations.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StationDetailSheet(station: station),
            ),
          ),
        ),
      );

      // Verify station title and operator badge
      expect(find.text('Suria KLCC Gentari Charging Hub'), findsOneWidget);
      expect(find.text('Gentari'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      // Verify Parking Level is displayed (Malaysian underground bay navigation)
      expect(find.text('Basement B1, Pillar B12'), findsOneWidget);

      // Verify connector types and kW
      expect(find.text('CCS2'), findsOneWidget);
      expect(find.text('180 kW • 3 bays'), findsOneWidget);

      // Scroll down to reveal How to Access guide and CTA
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify step-by-step How to Access guide
      expect(find.text('How to Access Charger'), findsOneWidget);
      expect(
        find.text('Enter via Jalan Ampang basement ramp into Carpark B1.'),
        findsOneWidget,
      );
      expect(
        find.text('Follow green EV Hub floor markings toward Pillar B12.'),
        findsOneWidget,
      );

      // Scroll further down to reveal Navigation CTA button (past MicroSurveyCard)
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Navigation CTA button
      expect(find.text('Navigate to Station'), findsOneWidget);
    });
  });
}
