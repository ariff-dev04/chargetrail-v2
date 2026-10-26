import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('AppShell smoke test renders bottom navigation bar and tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ChargeTrailApp(),
      ),
    );

    // Verify bottom navigation destinations
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Route Planner'), findsOneWidget);
    expect(find.text('EV Garage'), findsOneWidget);

    // Switch to Route Planner Tab
    await tester.tap(find.text('Route Planner'));
    await tester.pumpAndSettle();
    expect(
      find.text('Corridor filtering & charging stops strategy (Module 6)'),
      findsOneWidget,
    );

    // Switch to EV Garage Tab
    await tester.tap(find.text('EV Garage'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Vehicle specs, battery capacity & consensus stats (Module 3)',
      ),
      findsOneWidget,
    );
  });
}
