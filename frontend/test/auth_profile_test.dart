import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/auth/presentation/auth_controller.dart';
import 'package:frontend/features/auth/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('UserProfile Model Unit Tests', () {
    test('UserProfile parses from JSON and serializes back idempotently', () {
      final user = UserProfile(
        id: 'user-uuid-1234',
        email: 'azman@chargetrail.my',
        fullName: 'Azman Ali',
        phoneNumber: '+60123456789',
        preferredConnector: 'CCS2',
        role: 'user',
        isActive: true,
        savedStationIds: const ['station-1', 'station-2'],
        createdAt: DateTime(2026, 1, 1),
      );

      final json = user.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, equals(user.id));
      expect(restored.email, equals('azman@chargetrail.my'));
      expect(restored.fullName, equals('Azman Ali'));
      expect(restored.preferredConnector, equals('CCS2'));
      expect(restored.savedStationIds.length, equals(2));
      expect(restored.isBookmarked('station-1'), isTrue);
      expect(restored.isBookmarked('station-999'), isFalse);
    });

    test('UserProfile copyWith updates attributes without mutating original', () {
      const user = UserProfile(
        id: 'user-1',
        email: 'original@mail.com',
        fullName: 'Original Name',
        savedStationIds: ['station-a'],
      );

      final updated = user.copyWith(
        fullName: 'Updated Name',
        preferredConnector: 'CHAdeMO',
        savedStationIds: ['station-a', 'station-b'],
      );

      expect(updated.fullName, equals('Updated Name'));
      expect(updated.preferredConnector, equals('CHAdeMO'));
      expect(updated.savedStationIds.length, equals(2));
      expect(user.fullName, equals('Original Name'));
    });
  });

  group('AuthNotifier Controller Unit Tests', () {
    test('Demo login, profile update, bookmark toggle, and logout cycle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);

      // 1. Initial State
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);

      // 2. Demo Driver Login
      await notifier.loginAsDemoDriver();
      var state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.currentUser?.fullName, contains('Ahmad Faiz'));

      // 3. Toggle Bookmark
      const newStationId = 'test-station-new-99';
      await notifier.toggleBookmark(newStationId);
      state = container.read(authControllerProvider);
      expect(state.currentUser?.isBookmarked(newStationId), isTrue);

      // Untoggle bookmark
      await notifier.toggleBookmark(newStationId);
      state = container.read(authControllerProvider);
      expect(state.currentUser?.isBookmarked(newStationId), isFalse);

      // 4. Update Profile Preferred Connector
      await notifier.updateProfile(preferredConnector: 'Type 2');
      state = container.read(authControllerProvider);
      expect(state.currentUser?.preferredConnector, equals('Type 2'));

      // 5. Logout
      await notifier.logout();
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders sign in form and switches to authenticated profile',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Unauthenticated Screen Elements
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue as Malaysian Demo Driver'), findsOneWidget);

      // Tap Demo Login Button
      await tester.tap(find.text('Continue as Malaysian Demo Driver'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Authenticated Screen Elements
      expect(find.text('EV Driver Profile'), findsOneWidget);
      expect(find.text('Ahmad Faiz (Demo)'), findsOneWidget);
      expect(find.text('Preferred Charging Connector'), findsOneWidget);
      expect(find.text('CCS2'), findsWidgets);
      expect(find.text('Type 2'), findsWidgets);
      expect(find.text('CHAdeMO'), findsWidgets);
      expect(find.textContaining('Saved Stations'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Tap Log Out
      await tester.tap(find.text('Log Out'));
      await tester.pump(const Duration(milliseconds: 100));

      // Confirms return to Sign In screen
      expect(find.text('Sign In'), findsWidgets);
    });
  });
}
