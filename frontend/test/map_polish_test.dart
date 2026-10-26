import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/config/map_tile_config.dart';
import 'package:frontend/core/services/location_service.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/community/data/community_repository.dart';
import 'package:frontend/features/routing/data/route_repository.dart';
import 'package:frontend/features/stations/data/station_local_cache.dart';
import 'package:frontend/features/stations/data/station_repository.dart';
import 'package:frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MapTileStyle Configuration & Switching Tests (Module 6.5)', () {
    test('MapTileStyle provides open-source raster tile URLs', () {
      expect(
        MapTileStyle.defaultStreet.urlTemplate,
        contains('World_Street_Map/MapServer'),
      );
      expect(
        MapTileStyle.satellite.urlTemplate,
        contains('World_Imagery/MapServer'),
      );
      expect(
        MapTileStyle.dark.urlTemplate,
        contains('World_Dark_Gray_Base/MapServer'),
      );

      expect(MapTileStyle.defaultStreet.label, equals('Street'));
      expect(MapTileStyle.satellite.label, equals('Satellite'));
      expect(MapTileStyle.dark.label, equals('Dark'));
    });

    test('mapTileStyleProvider state updates across style options', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mapTileStyleProvider), equals(MapTileStyle.defaultStreet));

      container.read(mapTileStyleProvider.notifier).setStyle(MapTileStyle.satellite);
      expect(container.read(mapTileStyleProvider), equals(MapTileStyle.satellite));

      container.read(mapTileStyleProvider.notifier).setStyle(MapTileStyle.dark);
      expect(container.read(mapTileStyleProvider), equals(MapTileStyle.dark));
    });

    testWidgets('MapStyleSelectorButton displays active map style and popup', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: MapStyleSelectorButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Street'), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });
  });

  group('Expanded 12-Station Malaysian Dataset Tests (Module 6.5)', () {
    test('StationLocalCache pre-seeds exactly 12 verified Malaysian stations', () {
      final stations = StationLocalCache.defaultMalaysianStations();
      expect(stations.length, equals(12));

      final names = stations.map((s) => s.name).toSet();

      // Greater KL / Selangor
      expect(names, contains('Suria KLCC Gentari Charging Hub'));
      expect(names, contains('Pavilion Bukit Bintang JomCharge'));
      expect(names, contains('IOI City Mall Putrajaya JomCharge'));
      expect(names, contains('Cyberjaya Tamarind Square Gentari'));
      expect(names, contains('Sunway Pyramid chargEV Station'));

      // Highways & Regional Hubs
      expect(names, contains('Genting Highlands SkyAvenue JomCharge'));
      expect(names, contains('Shell Recharge Tapah RSA Northbound'));
      expect(names, contains('Ipoh Sunway Lost World JomCharge'));
      expect(names, contains('Gurney Plaza Shell Recharge'));
      expect(names, contains('Shell Recharge Seremban RSA Southbound'));
      expect(names, contains('Ayer Keroh Overhead Bridge RSA Gentari'));
      expect(names, contains('Mid Valley Southkey Gentari Hub'));

      for (final s in stations) {
        expect(s.isVerified, isTrue);
        expect(s.latitude, inInclusiveRange(1.0, 7.0));
        expect(s.longitude, inInclusiveRange(99.0, 105.0));
        expect(s.howToAccess.isNotEmpty, isTrue);
      }
    });
  });

  group('GPS Location Service Tests (Module 6.5)', () {
    test('LocationService resolves realistic Malaysian GPS coordinates', () async {
      final service = LocationService();
      final pos = await service.determinePosition();

      expect(pos.latitude, closeTo(3.1343, 0.01));
      expect(pos.longitude, closeTo(101.6865, 0.01));
      expect(pos.label, contains('Kuala Lumpur'));
    });

    testWidgets('UserLocationMarkerWidget renders pulsing radar dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserLocationMarkerWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(UserLocationMarkerWidget), findsOneWidget);
    });
  });

  group('Unified Wi-Fi ApiConfig BaseUrl Verification', () {
    test('All 5 repositories instantiate cleanly with ApiConfig.baseUrl', () {
      expect(ApiConfig.baseUrl.startsWith('http'), isTrue);

      final stationRepo = StationRepository();
      final authRepo = AuthRepository();
      final commRepo = CommunityRepository();
      final vehRepo = VehicleRepository();
      final routeRepo = RouteRepository();

      expect(stationRepo, isNotNull);
      expect(authRepo, isNotNull);
      expect(commRepo, isNotNull);
      expect(vehRepo, isNotNull);
      expect(routeRepo, isNotNull);
    });
  });
}
