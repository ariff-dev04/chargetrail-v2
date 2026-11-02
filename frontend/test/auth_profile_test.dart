import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/auth/presentation/auth_controller.dart';
import 'package:frontend/features/auth/presentation/profile_screen.dart';
import 'package:frontend/presentation/screens/app_shell_screen.dart';
import 'package:frontend/presentation/widgets/auth_gate_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers/mock_auth_helpers.dart';

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

    test('deleteAccount purges session and resets state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.loginAsDemoDriver();
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      await notifier.deleteAccount();
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(container.read(authControllerProvider).currentUser, isNull);
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
      expect(find.text('Saved Stations (0)'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Tap Log Out
      await tester.tap(find.text('Log Out'));
      await tester.pump(const Duration(milliseconds: 100));

      // Confirms return to Sign In screen
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('ProfileScreen shows Delete Account button and triggers confirmation dialog', (tester) async {
      final container = ProviderContainer();
      await container.read(authControllerProvider.notifier).loginAsDemoDriver();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Delete Account & Data button exists
      expect(find.text('Delete Account & Data'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);

      // Tap Delete Account & Data
      await tester.tap(find.text('Delete Account & Data'));
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog opens
      expect(find.text('Delete Account & Personal Data?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Delete Account & Personal Data?'), findsNothing);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      // Open dialog again and tap Delete Permanently
      await tester.tap(find.text('Delete Account & Data'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Delete Permanently'));
      await tester.pump(const Duration(milliseconds: 100));

      // Account should now be deleted and unauthenticated
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });
  });

  group('AuthGateView & AppShellScreen Widget Tests', () {
    testWidgets('AuthGateView renders branding, demo login, and toggles signup mode', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthGateView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Branding Header
      expect(find.byIcon(Icons.ev_station_rounded), findsOneWidget);
      expect(find.text('ChargeTrail v2'), findsOneWidget);
      expect(find.text('Malaysia EV Charging & Open Highway Corridors'), findsOneWidget);

      // Instant Demo Login Button
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.text('Continue with Instant Demo Account'), findsOneWidget);

      // Default Sign In fields
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Display Name'), findsNothing);

      // Switch to Create Account mode
      await tester.tap(find.text('Create Account'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Preferred Connector'), findsOneWidget);
      expect(find.text('CCS2'), findsOneWidget);
      expect(find.text('Type 2'), findsOneWidget);
      expect(find.text('CHAdeMO'), findsOneWidget);
    });

    testWidgets('AppShellScreen switches from AuthGateView to authenticated tabs on demo login', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppShellScreen(),
          ),
        ),
      );
      // Wait for initial bootstrap
      await tester.pump(const Duration(milliseconds: 200));

      // Initially unauthenticated, shows AuthGateView
      expect(find.byType(AuthGateView), findsOneWidget);
      expect(find.text('Continue with Instant Demo Account'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Tap 1-Tap Demo Login
      await tester.tap(find.text('Continue with Instant Demo Account'));
      await tester.pump(const Duration(milliseconds: 200));

      // Now authenticated, shows 4-tab shell
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Route Planner'), findsOneWidget);
      expect(find.text('EV Garage'), findsOneWidget);
      expect(find.text('Profile & Saved'), findsOneWidget);

      // Drain any background network timeouts from instantiated tabs
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('AuthRepository Remote API & Error Handling Unit Tests', () {
    test('register succeeds and saves session on 201', () async {
      final repo = createMockAuthRepository((options) async {
        return jsonResponseBody({
          'access_token': 'token-reg-123',
          'user': mockUserJson(id: 'u-reg-1', email: 'driver@chargetrail.my'),
        }, 201);
      });

      final result = await repo.register(
        email: 'driver@chargetrail.my',
        password: 'password123',
        fullName: 'Driver Test',
      );

      expect(result.token, equals('token-reg-123'));
      expect(result.user.email, equals('driver@chargetrail.my'));
      final session = await repo.loadPersistedSession();
      expect(session.token, equals('token-reg-123'));
    });

    test('register throws 409 conflict exception', () async {
      final repo = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Email already registered'}, 409);
      });

      await expectLater(
        () => repo.register(
          email: 'driver@chargetrail.my',
          password: 'password123',
          fullName: 'Driver Test',
        ),
        throwsExceptionWith('An account with this email already exists.'),
      );
    });

    test('register throws 422 with parsed detail message or default validation message', () async {
      final repoWithDetail = createMockAuthRepository((options) async {
        return jsonResponseBody(
          {'detail': 'Password must contain at least 6 characters'},
          422,
        );
      });

      await expectLater(
        () => repoWithDetail.register(
          email: 'driver@chargetrail.my',
          password: '123',
          fullName: 'Driver Test',
        ),
        throwsExceptionWith('Password must contain at least 6 characters'),
      );

      final repoDefault422 = createMockAuthRepository((options) async {
        return jsonResponseBody({}, 422);
      });

      await expectLater(
        () => repoDefault422.register(
          email: 'driver@chargetrail.my',
          password: '123',
          fullName: 'Driver Test',
        ),
        throwsExceptionWith('Please enter a valid email and a password of at least 6 characters.'),
      );
    });

    test('register throws connection error exception on network/server failure', () async {
      final repo = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Internal error'}, 500);
      });

      await expectLater(
        () => repo.register(
          email: 'driver@chargetrail.my',
          password: 'password123',
          fullName: 'Driver Test',
        ),
        throwsExceptionWith('Unable to reach authentication server.'),
      );
    });

    test('login succeeds and saves session on 200', () async {
      final repo = createMockAuthRepository((options) async {
        return jsonResponseBody({
          'access_token': 'token-login-456',
          'user': mockUserJson(id: 'u-login-1', email: 'driver@chargetrail.my'),
        }, 200);
      });

      final result = await repo.login(
        email: 'driver@chargetrail.my',
        password: 'password123',
      );

      expect(result.token, equals('token-login-456'));
      expect(result.user.email, equals('driver@chargetrail.my'));
    });

    test('login throws 401 or 404 credential exception', () async {
      final repo401 = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Unauthorized'}, 401);
      });

      await expectLater(
        () => repo401.login(
          email: 'driver@chargetrail.my',
          password: 'wrongpassword',
        ),
        throwsExceptionWith('Invalid email or password credentials.'),
      );

      final repo404 = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Not Found'}, 404);
      });

      await expectLater(
        () => repo404.login(
          email: 'driver@chargetrail.my',
          password: 'wrongpassword',
        ),
        throwsExceptionWith('Invalid email or password credentials.'),
      );
    });

    test('login throws 422 validation exception', () async {
      final repo422 = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Unprocessable Entity'}, 422);
      });

      await expectLater(
        () => repo422.login(
          email: 'bad-email',
          password: '',
        ),
        throwsExceptionWith('Please enter a valid email address and password.'),
      );
    });

    test('login throws connection error exception on network/server failure', () async {
      final repo = createMockAuthRepository((options) async {
        return jsonResponseBody({'detail': 'Bad Gateway'}, 502);
      });

      await expectLater(
        () => repo.login(
          email: 'driver@chargetrail.my',
          password: 'password123',
        ),
        throwsExceptionWith('Unable to reach authentication server.'),
      );
    });
  });
}
