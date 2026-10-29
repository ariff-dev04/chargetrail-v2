import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/routing/presentation/widgets/route_advisory_banner.dart';

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
}
