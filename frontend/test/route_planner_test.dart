import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/routing/data/route_repository.dart';
import 'package:frontend/features/routing/domain/route_models.dart';
import 'package:frontend/features/routing/presentation/route_controller.dart';
import 'package:frontend/features/routing/presentation/route_planner_screen.dart';
import 'package:frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Route Models & Range Anxiety Physics (KF10, KF14)', () {
    test('RoutePlanResult parses JSON and classifies status flags', () {
      final json = {
        'origin_name': 'Kuala Lumpur',
        'destination_name': 'Putrajaya',
        'total_distance_km': 35.5,
        'estimated_drive_minutes': 28,
        'total_charging_minutes': 0,
        'total_trip_minutes': 28,
        'starting_soc_percent': 80,
        'projected_destination_soc_without_charging': 71,
        'final_arrival_soc_percent': 71,
        'total_energy_kwh': 5.1,
        'range_anxiety_status': 'safe',
        'status_summary': 'Reachable safely',
        'vehicle_summary': 'Proton e.MAS 7 Prime',
        'polyline_points': [
          {'latitude': 3.15, 'longitude': 101.71},
          {'latitude': 2.96, 'longitude': 101.71},
        ],
        'recommended_stops': [],
        'corridor_stations': [],
      };

      final plan = RoutePlanResult.fromJson(json);
      expect(plan.isSafe, isTrue);
      expect(plan.isCritical, isFalse);
      expect(plan.totalDistanceKm, equals(35.5));
      expect(plan.recommendedStops.length, equals(0));
    });

    test('RouteRepository calculates short trip as safe without stops', () async {
      final repo = RouteRepository();
      final hubs = RouteRepository.defaultHubs;
      final vehicle = VehicleRepository.defaultPresets.first; // Proton e.MAS 7

      final plan = await repo.calculateRoutePlan(
        origin: hubs[0], // KLCC
        destination: hubs[2], // Putrajaya
        vehicle: vehicle,
        startingSocPercent: 80,
      );

      expect(plan.isSafe, isTrue);
      expect(plan.recommendedStops.isEmpty, isTrue);
      expect(plan.finalArrivalSocPercent, greaterThan(65));
      expect(plan.totalChargingMinutes, equals(0));
    });

    test('RouteRepository calculates long trip at 55% SoC as critical with Tapah stop', () async {
      final repo = RouteRepository();
      final hubs = RouteRepository.defaultHubs;
      final vehicle = VehicleRepository.defaultPresets.first; // Proton e.MAS 7

      final plan = await repo.calculateRoutePlan(
        origin: hubs[0], // KLCC
        destination: hubs[1], // Penang
        vehicle: vehicle,
        startingSocPercent: 55,
      );

      expect(plan.isCritical, isTrue);
      expect(plan.totalDistanceKm, greaterThan(300.0));
      expect(plan.recommendedStops.length, greaterThanOrEqualTo(1));
      expect(plan.recommendedStops.first.station.name, contains('Tapah'));
      expect(plan.finalArrivalSocPercent, greaterThanOrEqualTo(20));
      expect(plan.totalChargingMinutes, greaterThan(0));
    });
  });

  group('RouteNotifier Controller Tests (KF15)', () {
    test('Preset changes update origin, destination, and recalculate plan', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(routeControllerProvider.notifier);
      final hubs = RouteRepository.defaultHubs;

      // Apply Safe Preset
      notifier.applyPreset(
        origin: hubs[0],
        destination: hubs[2],
        startingSoc: 85,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(routeControllerProvider);
      expect(state.origin.name, contains('Kuala Lumpur'));
      expect(state.destination.name, contains('Putrajaya'));
      expect(state.startingSocPercent, equals(85));
      expect(state.currentPlan?.isSafe, isTrue);
    });
  });

  group('RoutePlannerScreen Widget Tests', () {
    testWidgets('Renders endpoints, starting SoC slider, presets, and telemetry card',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RoutePlannerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Endpoints and Controls
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Starting Battery SoC:'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Verify Quick Preset Action Chips
      expect(find.text('KL -> Putrajaya (Safe)'), findsOneWidget);
      expect(find.text('KL -> Penang (Needs Stop)'), findsOneWidget);

      // Tap Safe Preset
      await tester.tap(find.text('KL -> Putrajaya (Safe)'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Telemetry Card appears with Safe Range
      expect(find.textContaining('Safe Range'), findsWidgets);
      expect(find.text('Total Distance'), findsWidgets);
    });
  });
}
