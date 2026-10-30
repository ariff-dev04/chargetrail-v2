import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/community/presentation/widgets/suggest_station_edit_sheet.dart';
import 'package:frontend/features/routing/presentation/widgets/route_advisory_banner.dart';
import 'package:frontend/features/stations/domain/station_model.dart';
import 'package:frontend/features/stations/presentation/widgets/operator_marker_badge.dart';

void main() {
  testWidgets('RouteAdvisoryBanner renders standard disclaimer text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteAdvisoryBanner(),
        ),
      ),
    );

    expect(find.byType(RouteAdvisoryBanner), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('Driver Advisory & Open-Data Disclaimer'), findsOneWidget);
    expect(find.textContaining('Northbound/Utara vs Southbound/Selatan'), findsOneWidget);
  });

  testWidgets('RouteAdvisoryBanner renders compact disclaimer text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteAdvisoryBanner(compact: true),
        ),
      ),
    );

    expect(find.byType(RouteAdvisoryBanner), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.textContaining('Verify Carriageway Direction'), findsOneWidget);
  });

  testWidgets('OperatorBrandTheme resolves Gentari, Tesla, JomCharge, and fallback correctly', (tester) async {
    final gentari = ChargingStation(
      id: 'g1',
      name: 'Gentari R&R Seremban',
      operatorName: 'Gentari',
      address: 'PLUS E2',
      city: 'Seremban',
      state: 'Negeri Sembilan',
      latitude: 2.7,
      longitude: 101.9,
      maxPowerKw: 180.0,
      plugTypes: [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 2)],
    );
    final themeGtr = OperatorBrandTheme.fromStation(gentari);
    expect(themeGtr.tag, 'GTR');
    expect(themeGtr.label, 'Gentari');

    final tesla = ChargingStation(
      id: 't1',
      name: 'Tesla Supercharger Pavilion KL',
      operatorName: 'Tesla',
      address: 'Pavilion KL',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan',
      latitude: 3.14,
      longitude: 101.71,
      maxPowerKw: 250.0,
      plugTypes: [PlugInfo(type: 'Tesla', powerKw: 250.0, count: 4)],
    );
    final themeTesla = OperatorBrandTheme.fromStation(tesla);
    expect(themeTesla.tag, 'TSLA');
    expect(themeTesla.label, 'Tesla');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OperatorBrandChip(station: gentari),
              OperatorMapMarker(station: gentari, isSelected: false, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(OperatorBrandChip), findsOneWidget);
    expect(find.text('Gentari'), findsOneWidget);
    expect(find.text(' • DC 180kW'), findsOneWidget);
    expect(find.byType(OperatorMapMarker), findsOneWidget);
    expect(find.text('GTR'), findsOneWidget);
  });

  testWidgets('SuggestStationEditSheet renders edit form fields and options', (tester) async {
    final station = ChargingStation(
      id: 's1',
      name: 'Petronas R&R Dengkil',
      address: 'ELITE Highway',
      city: 'Dengkil',
      state: 'Selangor',
      latitude: 2.86,
      longitude: 101.62,
      maxPowerKw: 180.0,
      chargingCostMyr: 1.40,
      parkingLevel: 'Highway R&R / Open Bay',
      description: 'Original access guide',
      amenities: ['Restroom', 'Dining'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestStationEditSheet(
            station: station,
            onSubmitted: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Suggest an Edit'), findsOneWidget);
    expect(find.text('Highway R&R / Open Bay'), findsOneWidget);
    expect(find.text('Submit Edit Proposal (+5 pts)'), findsOneWidget);
  });
}
