import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:frontend/features/vehicles/domain/vehicle_model.dart';
import 'package:frontend/features/vehicles/presentation/garage_screen.dart';
import 'package:frontend/features/vehicles/presentation/vehicle_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VehicleProfile Physics & Range Calculations (KF11)', () {
    const testEv = VehicleProfile(
      id: 'test-ev-1',
      brand: 'Proton',
      modelName: 'e.MAS 7 Prime',
      batteryCapacityKwh: 60.0,
      usableRangeKm: 400.0,
      efficiencyWhPerKm: 150.0,
      maxDcChargeKw: 100.0,
      reserveSocPercent: 15,
    );

    test('rangeAtSocKm calculates exact proportional range', () {
      expect(testEv.rangeAtSocKm(100), equals(400.0));
      expect(testEv.rangeAtSocKm(80), equals(320.0));
      expect(testEv.rangeAtSocKm(50), equals(200.0));
      expect(testEv.rangeAtSocKm(0), equals(0.0));
    });

    test('safeUsableRangeAtSocKm deducts safety reserve buffer', () {
      // At 80% SoC with 15% reserve buffer, effective usable SoC is 65% -> 260 km
      expect(testEv.safeUsableRangeAtSocKm(80), equals(260.0));
      // At 15% SoC (equal to reserve), safe route range is 0 km
      expect(testEv.safeUsableRangeAtSocKm(15), equals(0.0));
      // Below reserve buffer, safe route range stays 0 km
      expect(testEv.safeUsableRangeAtSocKm(10), equals(0.0));
    });

    test('estimateChargeMinutes20To80 models realistic charge curve duration', () {
      // 100kW vehicle on a 180kW DC charger -> effective 100kW
      final minsFast = testEv.estimateChargeMinutes20To80(180.0);
      expect(minsFast, inInclusiveRange(20, 30));

      // 100kW vehicle on a slower 50kW DC charger -> throttled by station to 50kW
      final minsSlow = testEv.estimateChargeMinutes20To80(50.0);
      expect(minsSlow, inInclusiveRange(45, 60));
    });
  });

  group('VehicleNotifier Controller Unit Tests (KF12)', () {
    test('State management for SoC slider, active vehicle switch, and preset addition', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(vehicleControllerProvider.notifier);

      // Verify initial Malaysian garage has active vehicle
      final initialActive = container.read(vehicleControllerProvider).activeVehicle;
      expect(initialActive.brand, equals('Proton'));
      expect(initialActive.modelName, equals('e.MAS 7 Prime'));

      // 1. Update SoC slider
      notifier.setSimulatedSoc(60);
      expect(container.read(vehicleControllerProvider).simulatedCurrentSoc, equals(60));

      // 2. Add vehicle from preset (Tesla Model 3)
      final teslaPreset = VehicleRepository.defaultPresets.firstWhere((p) => p.brand == 'Tesla');
      await notifier.addVehicleFromPreset(teslaPreset);
      final vehicles = container.read(vehicleControllerProvider).garageVehicles;
      expect(vehicles.any((v) => v.brand == 'Tesla'), isTrue);

      // 3. Switch active vehicle to Tesla
      final tesla = vehicles.firstWhere((v) => v.brand == 'Tesla');
      await notifier.setPrimaryVehicle(tesla.id);
      expect(container.read(vehicleControllerProvider).activeVehicle.brand, equals('Tesla'));

      // 4. Update reserve SoC buffer
      await notifier.updateReserveSoc(tesla.id, 20);
      final updatedTesla = container.read(vehicleControllerProvider).activeVehicle;
      expect(updatedTesla.reserveSocPercent, equals(20));
    });
  });

  group('GarageScreen Widget Tests', () {
    testWidgets('Renders active EV telemetry, SoC slider, and garage list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GarageScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Screen Header & Hero Card
      expect(find.text('EV Garage & Battery Telemetry'), findsOneWidget);
      expect(find.text('Active EV'), findsOneWidget);
      expect(find.textContaining('Current Battery SoC:'), findsOneWidget);
      expect(find.textContaining('Total Range at'), findsOneWidget);
      expect(find.textContaining('Safe Route Range'), findsOneWidget);

      // Verify Garage List
      expect(find.textContaining('My EV Garage'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Verify Add EV button opens preset selection sheet
      expect(find.text('Add EV'), findsOneWidget);
      await tester.tap(find.text('Add EV'));
      await tester.pumpAndSettle();

      expect(find.text('Add Vehicle to Garage (KF11)'), findsOneWidget);
      expect(find.text('Tesla Model 3 Long Range AWD'), findsOneWidget);
      expect(find.text('Hyundai IONIQ 5 Max AWD'), findsOneWidget);
    });
  });
}
