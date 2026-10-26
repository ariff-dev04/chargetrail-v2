import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppShell smoke test renders bottom navigation bar and tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ChargeTrailApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify bottom navigation destinations
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Route Planner'), findsOneWidget);
    expect(find.text('EV Garage'), findsOneWidget);
    expect(find.text('Profile & Saved'), findsOneWidget);

    // Switch to Route Planner Tab
    await tester.tap(find.text('Route Planner'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Starting Battery SoC:'), findsOneWidget);

    // Switch to EV Garage Tab
    await tester.tap(find.text('EV Garage'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('EV Garage & Battery Telemetry'), findsOneWidget);

    // Switch to Profile & Saved Tab
    await tester.tap(find.text('Profile & Saved'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sign In'), findsWidgets);
  });
}
