import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/routing/domain/route_models.dart';
import 'package:frontend/features/routing/presentation/navigation_launcher.dart';
import 'package:frontend/features/stations/domain/station_model.dart';

void main() {
  group('NavigationLauncher Exact Coordinate Tests', () {
    const origin = PlaceSuggestion(
      name: 'Suria KLCC',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
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

    test('buildGoogleMapsSingleUrl uses exact 6-decimal coordinates in destination param', () {
      final url = NavigationLauncher.buildGoogleMapsSingleUrl(
        3.1578,
        101.7118,
        stationName: 'Suria KLCC Gentari Hub',
        city: 'Kuala Lumpur',
      );

      expect(url, contains('destination=3.157800,101.711800'));
      expect(url, contains('travelmode=driving'));
      expect(url, isNot(contains('Suria+KLCC')));
      expect(url, isNot(contains('Kuala+Lumpur')));
    });

    test('buildGoogleMapsMultiStopUrl uses exact coordinates for origin, destination, and waypoints', () {
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

      final plan = RoutePlanResult(
        originName: 'Suria KLCC',
        destinationName: 'Gurney Plaza',
        totalDistanceKm: 355.0,
        estimatedDriveMinutes: 240,
        totalChargingMinutes: 20,
        totalTripMinutes: 260,
        startingSocPercent: 50,
        projectedDestinationSocWithoutCharging: 5,
        finalArrivalSocPercent: 30,
        totalEnergyKwh: 48.0,
        rangeAnxietyStatus: 'critical_charging_required',
        statusSummary: 'Stop required',
        vehicleSummary: 'Proton e.MAS 7',
        polylinePoints: const [],
        recommendedStops: const [
          ChargingStopRecommendation(
            station: stopStation,
            distanceFromOriginKm: 150.0,
            detourDistanceKm: 0.5,
            arrivalSocPercent: 18,
            departureSocPercent: 80,
            energyAddedKwh: 35.0,
            estimatedChargeMinutes: 20,
            estimatedCostMyr: 56.0,
          ),
        ],
        corridorStations: const [],
      );

      final url = NavigationLauncher.buildGoogleMapsMultiStopUrl(
        plan: plan,
        origin: origin,
        destination: destination,
      );

      expect(url, contains('origin=3.157800,101.711800'));
      expect(url, contains('destination=5.437200,100.309600'));
      expect(url, contains('waypoints=4.313800%2C101.258200'));
      expect(url, isNot(contains('Suria+KLCC')));
      expect(url, isNot(contains('Gurney+Plaza')));
    });

    test('buildWazeUrl uses exact 6-decimal coordinates', () {
      final url = NavigationLauncher.buildWazeUrl(3.1578, 101.7118);
      expect(url, equals('https://waze.com/ul?ll=3.157800,101.711800&navigate=yes'));
    });
  });
}
