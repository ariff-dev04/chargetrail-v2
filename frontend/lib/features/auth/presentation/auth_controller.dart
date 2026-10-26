import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

/// State representation for authentication and active user session.
class AuthState {
  final UserProfile? currentUser;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null && token != null;

  AuthState copyWith({
    UserProfile? currentUser,
    bool clearCurrentUser = false,
    String? token,
    bool clearToken = false,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Dependency provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Riverpod controller managing user credentials, session restoration, and bookmarks.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    state = const AuthState(isLoading: true);
    Future.microtask(() => restoreSession());
    return state;
  }

  /// Restore cached session from local storage on app boot.
  Future<void> restoreSession() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final session = await repo.loadPersistedSession();
      state = state.copyWith(
        currentUser: session.user,
        token: session.token,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Register a new account.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String preferredConnector = 'CCS2',
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.register(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        preferredConnector: preferredConnector,
      );
      state = state.copyWith(
        currentUser: result.user,
        token: result.token,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Authenticate with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email: email, password: password);
      state = state.copyWith(
        currentUser: result.user,
        token: result.token,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Instantly authenticate with an offline local demo account.
  Future<void> loginAsDemoDriver() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    const demo = UserProfile(
      id: 'demo-ev-driver-my',
      email: 'driver.demo@chargetrail.my',
      fullName: 'Ahmad Faiz (Demo)',
      phoneNumber: '+60123456789',
      preferredConnector: 'CCS2',
      savedStationIds: [
        '9ec6c0f7-48d9-48b1-ad1b-0e6a157fa1bf', // Suria KLCC
        'c3d4e5f6-a1b2-4c3d-0e4f-5a6b7c8d9e0f', // Tapah RSA
      ],
    );
    const demoToken = 'local-offline-demo-token';
    final repo = ref.read(authRepositoryProvider);
    await repo.saveSession(demo, demoToken);

    state = state.copyWith(
      currentUser: demo,
      token: demoToken,
      isLoading: false,
    );
  }

  /// Update mutable fields on user profile.
  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? preferredConnector,
  }) async {
    final token = state.token;
    if (token == null || state.currentUser == null) return false;

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final updated = await repo.updateProfile(
        token: token,
        fullName: fullName,
        phoneNumber: phoneNumber,
        preferredConnector: preferredConnector,
      );
      state = state.copyWith(currentUser: updated, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Toggle bookmark status for a charging station.
  Future<void> toggleBookmark(String stationId) async {
    final user = state.currentUser;
    final token = state.token ?? 'offline-token';
    if (user == null) {
      // If user is guest, activate demo session transparently to store bookmark
      await loginAsDemoDriver();
      return toggleBookmark(stationId);
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.toggleBookmark(
        token: token,
        stationId: stationId,
        currentUser: user,
      );
      final updatedUser = user.copyWith(savedStationIds: result.savedIds);
      state = state.copyWith(currentUser: updatedUser);
    } catch (_) {
      // Fallback local toggle
      final currentList = List<String>.from(user.savedStationIds);
      if (currentList.contains(stationId)) {
        currentList.remove(stationId);
      } else {
        currentList.add(stationId);
      }
      final updatedUser = user.copyWith(savedStationIds: currentList);
      state = state.copyWith(currentUser: updatedUser);
    }
  }

  /// Terminate session and erase stored credentials.
  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.clearSession();
    state = const AuthState();
  }
}

/// Global provider for AuthController.
final authControllerProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
