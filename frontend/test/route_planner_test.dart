import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/routing/data/route_repository.dart';
import 'package:frontend/features/routing/domain/route_models.dart';
import 'package:frontend/features/routing/presentation/navigation_launcher.dart';
import 'package:frontend/features/routing/presentation/route_controller.dart';
import 'package:frontend/features/routing/presentation/route_planner_screen.dart';
import 'package:frontend/features/routing/presentation/widgets/charging_stop_tile.dart';
import 'package:frontend/features/routing/presentation/widgets/route_search_card.dart';
import 'package:frontend/features/routing/presentation/widgets/route_telemetry_card.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:frontend/features/vehicles/domain/vehicle_model.dart';
import 'package:frontend/features/vehicles/presentation/vehicle_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTestCorridorStations = [
  ChargingStation(
    id: 'stop-tapah',
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
    id: 'alt-simpang-pulai',
    name: 'Shell Recharge Simpang Pulai Layby Northbound',
    operatorName: 'Shell Recharge',
    address: 'North-South Expressway KM 290.4 Northbound, 31300 Simpang Pulai, Perak',
    city: 'Simpang Pulai',
    state: 'Perak',
    latitude: 4.5162,
    longitude: 101.1458,
    plugTypes: [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 2)],
    maxPowerKw: 180.0,
    isAvailable: true,
    is24Hours: true,
    chargingCostMyr: 1.60,
    parkingFeeMyr: 0.0,
    parkingLevel: 'Layby Northbound ParkEasy HPC Bay',
    operationHours: '24 Hours',
    amenities: ['Restroom', 'Petrol Station', 'Convenience Store'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Exit PLUS highway at Simpang Pulai Layby Northbound.'),
    ],
    rating: 4.7,
    reviewCount: 45,
    source: 'community',
    isVerified: true,
  ),
  ChargingStation(
    id: 'alt-ipoh-lost-world',
    name: 'Ipoh Sunway Lost World JomCharge',
    operatorName: 'JomCharge',
    address: 'No. 1, Persiaran Lagun Sunway 1, 31150 Ipoh, Perak',
    city: 'Ipoh',
    state: 'Perak',
    latitude: 4.6250,
    longitude: 101.1550,
    plugTypes: [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2)],
    maxPowerKw: 120.0,
    isAvailable: true,
    is24Hours: true,
    chargingCostMyr: 1.40,
    parkingFeeMyr: 2.00,
    parkingLevel: 'Open Carpark Zone A',
    operationHours: '24 Hours',
    amenities: ['Dining', 'Restroom', 'Theme Park', 'Hotel'],
    howToAccess: [
      AccessStep(stepNumber: 1, instruction: 'Enter Lost World visitor carpark.'),
    ],
    rating: 4.6,
    reviewCount: 30,
    source: 'community',
    isVerified: true,
  ),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StationLocalCache().saveStations(_kTestCorridorStations);
  });
  group('Route Models & Duration Formatting (KF10, KF14, Module 7.9)', () {
    test('formatDurationMinutes formats minutes into hours and minutes', () {
      expect(formatDurationMinutes(0), equals('0m'));
      expect(formatDurationMinutes(45), equals('45m'));
      expect(formatDurationMinutes(60), equals('1h'));
      expect(formatDurationMinutes(120), equals('2h'));
      expect(formatDurationMinutes(500), equals('8h 20m'));
    });
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
      expect(plan.formattedDriveTime, equals('28m'));
      expect(plan.formattedTotalTripTime, equals('28m'));
    });
    test('RouteRepository calculates short trip as safe without stops', () async {
      final repo = RouteRepository();
      final hubs = RouteRepository.defaultHubs;
      final vehicle = VehicleRepository.defaultPresets.first;
      final plan = await repo.calculateRoutePlan(
        origin: hubs[0],
        destination: hubs[2],
        vehicle: vehicle,
        startingSocPercent: 80,
      );
      expect(plan.isSafe, isTrue);
      expect(plan.recommendedStops.isEmpty, isTrue);
    });
    test('RouteRepository calculates long trip at 55% SoC as critical with Tapah stop', () async {
      final repo = RouteRepository();
      final hubs = RouteRepository.defaultHubs;
      final vehicle = VehicleRepository.defaultPresets.first;
      final plan = await repo.calculateRoutePlan(
        origin: hubs[0],
        destination: hubs[1],
        vehicle: vehicle,
        startingSocPercent: 55,
      );
      expect(plan.isCritical, isTrue);
      expect(plan.totalDistanceKm, greaterThan(300.0));
      expect(plan.recommendedStops.first.station.name, equals('TNB Electron Tapah R&R Northbound'));
      expect(plan.corridorStations.every((s) => !s.name.toLowerCase().contains('southbound')), isTrue);
      expect(plan.recommendedStops.first.corridorLat, isNotNull);
      expect(plan.recommendedStops.first.nearbyAlternatives.isNotEmpty, isTrue);
      expect(plan.recommendedStops.first.nearbyAlternatives.any((a) => a.name.contains('Simpang Pulai') || a.name.contains('Ipoh')), isTrue);
    });
    test('swapStopStation swaps stop to vicinity alternative and updates Google Maps waypoints', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(routeControllerProvider.notifier);
      final hubs = RouteRepository.defaultHubs;
      notifier.setOrigin(hubs[0]);
      notifier.setDestination(hubs[1]);
      await notifier.calculateRoute();
      final initialPlan = container.read(routeControllerProvider).currentPlan;
      expect(initialPlan, isNotNull);
      expect(initialPlan!.recommendedStops.isNotEmpty, isTrue);
      final oldStop = initialPlan.recommendedStops.first;
      expect(oldStop.nearbyAlternatives.isNotEmpty, isTrue);
      final altStation = oldStop.nearbyAlternatives.first;
      await notifier.swapStopStation(0, altStation);
      final updatedPlan = container.read(routeControllerProvider).currentPlan!;
      expect(updatedPlan.recommendedStops.first.station.id, equals(altStation.id));
      expect(updatedPlan.recommendedStops.first.station.name, equals(altStation.name));
      final googleMapsUrl = NavigationLauncher.buildGoogleMapsMultiStopUrl(
        origin: container.read(routeControllerProvider).origin,
        destination: container.read(routeControllerProvider).destination,
        plan: updatedPlan,
      );
      expect(googleMapsUrl, contains('${altStation.latitude.toStringAsFixed(6)}%2C${altStation.longitude.toStringAsFixed(6)}'));
    });
    test('RouteRepository searchPlaces filters catalog and returns matches', () async {
      final repo = RouteRepository();
      final places = await repo.searchPlaces('Penang');
      expect(places.isNotEmpty, isTrue);
    });
  });
  group('NavigationLauncher Deep-Link URL Builder Tests', () {
    const origin = PlaceSuggestion(
      name: 'KLCC',
      city: 'KL',
      state: 'KL',
      latitude: 3.1578,
      longitude: 101.7118,
    );
    const destination = PlaceSuggestion(
      name: 'Gurney Plaza',
      city: 'George Town',
      state: 'Penang',
      latitude: 5.4372,
      longitude: 100.3096,
    );
    test('buildGoogleMapsMultiStopUrl includes charging stop coordinates in waypoints=', () {
      const stopStation = ChargingStation(
        id: 'stop-tapah',
        name: 'Tapah RSA Hub',
        operatorName: 'Shell Recharge',
        address: 'PLUS Highway KM 332',
        city: 'Tapah',
        state: 'Perak',
        latitude: 4.1950,
        longitude: 101.2789,
        maxPowerKw: 180,
        isVerified: true,
      );
      final plan = RoutePlanResult(
        originName: 'KLCC',
        destinationName: 'Penang',
        totalDistanceKm: 355.0,
        estimatedDriveMinutes: 240,
        totalChargingMinutes: 22,
        totalTripMinutes: 262,
        startingSocPercent: 55,
        projectedDestinationSocWithoutCharging: 8,
        finalArrivalSocPercent: 32,
        totalEnergyKwh: 48.0,
        rangeAnxietyStatus: 'critical_charging_required',
        statusSummary: 'Stop required',
        vehicleSummary: 'Proton e.MAS 7',
        polylinePoints: const [],
        recommendedStops: const [
          ChargingStopRecommendation(
            station: stopStation,
            distanceFromOriginKm: 152.0,
            detourDistanceKm: 0.5,
            arrivalSocPercent: 18,
            departureSocPercent: 80,
            energyAddedKwh: 38.0,
            estimatedChargeMinutes: 22,
            estimatedCostMyr: 53.20,
          ),
        ],
        corridorStations: const [],
      );
      final url = NavigationLauncher.buildGoogleMapsMultiStopUrl(
        plan: plan,
        origin: origin,
        destination: destination,
      );
      expect(url, contains('waypoints='));
      expect(url, contains('4.195'));
      expect(NavigationLauncher.buildWazeUrl(4.195, 101.2789), contains('waze.com'));
    });
  });
  group('RouteNotifier & Mutual-Exclusion Panels (Module 7.9)', () {
    test('Preset changes update origin, destination, and recalculate plan', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(routeControllerProvider.notifier);
      final hubs = RouteRepository.defaultHubs;
      notifier.applyPreset(
        origin: hubs[0],
        destination: hubs[2],
        startingSoc: 85,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(routeControllerProvider);
      expect(state.origin.name, contains('Kuala Lumpur'));
      expect(state.currentPlan?.isSafe, isTrue);
    });
    testWidgets('Active EV specs display and mutual-exclusion panels work seamlessly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const customActiveEv = VehicleProfile(
        id: 'test-tesla',
        brand: 'Tesla',
        modelName: 'Model 3 Long Range AWD',
        batteryCapacityKwh: 75.0,
        usableRangeKm: 629.0,
        efficiencyWhPerKm: 125.0,
        maxDcChargeKw: 250.0,
        connectorType: 'CCS2',
        isPrimary: true,
      );
      final mockPlan = RoutePlanResult(
        originName: 'KLCC',
        destinationName: 'Putrajaya',
        totalDistanceKm: 35.0,
        estimatedDriveMinutes: 28,
        totalChargingMinutes: 0,
        totalTripMinutes: 28,
        startingSocPercent: 80,
        projectedDestinationSocWithoutCharging: 70,
        finalArrivalSocPercent: 70,
        totalEnergyKwh: 5.0,
        rangeAnxietyStatus: 'safe',
        statusSummary: 'Reachable safely.',
        vehicleSummary: 'Tesla Model 3 Long Range AWD',
        polylinePoints: const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleControllerProvider.overrideWith(() => _MockVehicleNotifier(customActiveEv)),
            routeControllerProvider.overrideWith(() => _MockRouteNotifier(mockPlan)),
          ],
          child: const MaterialApp(
            home: RoutePlannerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('collapsed_search_pill')), findsOneWidget);
      expect(find.byKey(const Key('collapsed_telemetry_bar')), findsOneWidget);
      expect(find.textContaining('Tesla Model 3'), findsWidgets);
      await tester.tap(find.byKey(const Key('collapsed_search_pill')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RouteSearchCard), findsOneWidget);
      expect(find.text('Plan EV Route'), findsOneWidget);
      expect(find.byKey(const Key('collapsed_telemetry_bar')), findsOneWidget);
      await tester.tap(find.byTooltip('Expand'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('expanded_telemetry_sheet')), findsOneWidget);
      expect(find.byKey(const Key('collapsed_search_pill')), findsOneWidget);
      expect(find.textContaining('Active EV: Tesla Model 3 Long Range AWD'), findsOneWidget);
      await tester.tap(find.byKey(const Key('telemetry_collapse_button')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('collapsed_search_pill')), findsOneWidget);
      expect(find.byKey(const Key('collapsed_telemetry_bar')), findsOneWidget);
    });
    testWidgets('RouteTelemetryCard renders formatted durations and collapses/expands',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = RoutePlanResult(
        originName: 'KLCC',
        destinationName: 'Putrajaya',
        totalDistanceKm: 35.0,
        estimatedDriveMinutes: 28,
        totalChargingMinutes: 0,
        totalTripMinutes: 28,
        startingSocPercent: 80,
        projectedDestinationSocWithoutCharging: 70,
        finalArrivalSocPercent: 70,
        totalEnergyKwh: 5.0,
        rangeAnxietyStatus: 'safe',
        statusSummary: 'Reachable safely.',
        vehicleSummary: 'Proton e.MAS 7',
        polylinePoints: const [],
        recommendedStops: const [],
        corridorStations: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteTelemetryCard(
              plan: plan,
              isExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_telemetry_sheet')), findsOneWidget);
      expect(find.text('28m'), findsWidgets);
      await tester.tap(find.byKey(const Key('telemetry_collapse_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collapsed_telemetry_bar')), findsOneWidget);
      expect(find.text('35.0 km • 28m'), findsOneWidget);
    });
    testWidgets('ChargingStopTile renders vicinity swap chip and opens bottom modal',
        (tester) async {
      const stopStation = ChargingStation(
        id: 'stop-tapah',
        name: 'TNB Electron Tapah R&R Northbound',
        operatorName: 'TNB Electron',
        address: 'PLUS Highway KM 332',
        city: 'Tapah',
        state: 'Perak',
        latitude: 4.3138,
        longitude: 101.2582,
        maxPowerKw: 180,
        isVerified: true,
      );
      const altStation = ChargingStation(
        id: 'alt-simpang-pulai',
        name: 'Shell Recharge Simpang Pulai Layby Northbound',
        operatorName: 'Shell Recharge',
        address: 'PLUS Highway KM 290.4',
        city: 'Simpang Pulai',
        state: 'Perak',
        latitude: 4.5162,
        longitude: 101.1458,
        maxPowerKw: 180,
        isVerified: true,
      );
      const stop = ChargingStopRecommendation(
        station: stopStation,
        distanceFromOriginKm: 152.0,
        detourDistanceKm: 0.5,
        arrivalSocPercent: 20,
        departureSocPercent: 80,
        energyAddedKwh: 36.0,
        estimatedChargeMinutes: 18,
        estimatedCostMyr: 57.60,
        nearbyAlternatives: [altStation],
      );
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChargingStopTile(
                stopIndex: 0,
                stop: stop,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('swap_stop_button_0')), findsOneWidget);
      expect(find.textContaining('Swap Stop (1 in vicinity)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('swap_stop_button_0')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Vicinity Chargers Along Corridor'), findsOneWidget);
      expect(find.text('Prioritize Stop'), findsOneWidget);
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
class _MockRouteNotifier extends RouteNotifier {
  final RoutePlanResult _mockPlan;
  _MockRouteNotifier(this._mockPlan);
  @override
  RouteState build() {
    return RouteState(
      origin: RouteRepository.defaultHubs[0],
      destination: RouteRepository.defaultHubs[1],
      startingSocPercent: 55,
      currentPlan: _mockPlan,
      isLoading: false,
    );
  }
  @override
  Future<void> calculateRoute() async {}
}
