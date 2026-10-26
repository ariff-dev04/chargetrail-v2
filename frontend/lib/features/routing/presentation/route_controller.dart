import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/presentation/vehicle_controller.dart';
import '../data/route_repository.dart';
import '../domain/route_models.dart';

/// State representation for journey route planning and battery simulation.
class RouteState {
  final PlaceSuggestion origin;
  final PlaceSuggestion destination;
  final int startingSocPercent;
  final RoutePlanResult? currentPlan;
  final bool isLoading;
  final String? errorMessage;

  const RouteState({
    required this.origin,
    required this.destination,
    this.startingSocPercent = 55,
    this.currentPlan,
    this.isLoading = false,
    this.errorMessage,
  });

  RouteState copyWith({
    PlaceSuggestion? origin,
    PlaceSuggestion? destination,
    int? startingSocPercent,
    RoutePlanResult? currentPlan,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RouteState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      startingSocPercent: startingSocPercent ?? this.startingSocPercent,
      currentPlan: currentPlan ?? this.currentPlan,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Dependency provider for RouteRepository.
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository();
});

/// Riverpod controller coordinating travel endpoints, battery SoC, and route simulation.
class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() {
    final hubs = RouteRepository.defaultHubs;
    final defaultOrigin = hubs[0]; // Kuala Lumpur (KLCC)
    final defaultDest = hubs[1]; // Penang (Gurney Plaza)

    state = RouteState(
      origin: defaultOrigin,
      destination: defaultDest,
      startingSocPercent: 55,
      isLoading: true,
    );

    Future.microtask(() => calculateRoute());
    return state;
  }

  /// Update departure origin landmark.
  void setOrigin(PlaceSuggestion origin) {
    state = state.copyWith(origin: origin);
    calculateRoute();
  }

  /// Update arrival destination landmark.
  void setDestination(PlaceSuggestion dest) {
    state = state.copyWith(destination: dest);
    calculateRoute();
  }

  /// Swap origin and destination endpoints.
  void swapOriginDestination() {
    final oldOrigin = state.origin;
    state = state.copyWith(
      origin: state.destination,
      destination: oldOrigin,
    );
    calculateRoute();
  }

  /// Update simulated battery State of Charge at departure.
  void setStartingSoc(int soc) {
    state = state.copyWith(startingSocPercent: soc.clamp(10, 100));
    calculateRoute();
  }

  /// Apply one-click route preset for rapid demonstration.
  void applyPreset({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required int startingSoc,
  }) {
    state = state.copyWith(
      origin: origin,
      destination: destination,
      startingSocPercent: startingSoc,
    );
    calculateRoute();
  }

  /// Trigger route simulation with active EV profile and starting battery percentage.
  Future<void> calculateRoute() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repo = ref.read(routeRepositoryProvider);
      final activeVehicle = ref.read(vehicleControllerProvider).activeVehicle;

      final plan = await repo.calculateRoutePlan(
        origin: state.origin,
        destination: state.destination,
        vehicle: activeVehicle,
        startingSocPercent: state.startingSocPercent,
      );

      state = state.copyWith(
        currentPlan: plan,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to calculate route: $e',
      );
    }
  }
}

/// Global provider for RouteController.
final routeControllerProvider =
    NotifierProvider<RouteNotifier, RouteState>(RouteNotifier.new);
