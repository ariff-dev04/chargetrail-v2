import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:frontend/features/stations/presentation/widgets/station_detail_sheet.dart';
import 'package:frontend/features/stations/presentation/widgets/station_filter_bar.dart';

void main() {
  group('ChargingStation & PlugInfo Serialization Tests', () {
    test('ChargingStation parses JSON and serializes back idempotently', () {
      final sample = StationLocalCache.defaultMalaysianStations().first;
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
    final stations = StationLocalCache.defaultMalaysianStations();
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
      final station = StationLocalCache.defaultMalaysianStations().first;

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

      // Scroll further down to reveal Navigation CTA button
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify Navigation CTA button
      expect(find.text('Navigate to Station'), findsOneWidget);
    });
  });
}
