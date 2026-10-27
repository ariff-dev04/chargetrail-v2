import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/domain/station_model.dart';
import '../../vehicles/presentation/vehicle_controller.dart';
import '../data/route_repository.dart';
import '../domain/route_models.dart';

/// State representation for journey route planning and battery simulation.
class RouteState {
  final PlaceSuggestion origin;
  final PlaceSuggestion destination;
  final int startingSocPercent;
  final RoutePlanResult? currentPlan;
  final List<String> preferredStopIds;
  final bool isLoading;
  final String? errorMessage;

  const RouteState({
    required this.origin,
    required this.destination,
    this.startingSocPercent = 55,
    this.currentPlan,
    this.preferredStopIds = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  RouteState copyWith({
    PlaceSuggestion? origin,
    PlaceSuggestion? destination,
    int? startingSocPercent,
    RoutePlanResult? currentPlan,
    List<String>? preferredStopIds,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RouteState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      startingSocPercent: startingSocPercent ?? this.startingSocPercent,
      currentPlan: currentPlan ?? this.currentPlan,
      preferredStopIds: preferredStopIds ?? this.preferredStopIds,
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
  bool _disposed = false;

  @override
  RouteState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });

    final hubs = RouteRepository.defaultHubs;
    final defaultOrigin = hubs[0]; // Kuala Lumpur (KLCC)
    final defaultDest = hubs[1]; // Penang (Gurney Plaza)

    state = RouteState(
      origin: defaultOrigin,
      destination: defaultDest,
      startingSocPercent: 55,
      isLoading: true,
    );

    ref.listen<VehicleState>(vehicleControllerProvider, (prev, next) {
      if (prev?.activeVehicle.id != next.activeVehicle.id ||
          prev?.activeVehicle.batteryCapacityKwh != next.activeVehicle.batteryCapacityKwh ||
          prev?.activeVehicle.efficiencyWhPerKm != next.activeVehicle.efficiencyWhPerKm ||
          prev?.activeVehicle.maxDcChargeKw != next.activeVehicle.maxDcChargeKw) {
        calculateRoute();
      }
    });

    Future.microtask(() => calculateRoute());
    return state;
  }

  /// Update departure origin landmark.
  void setOrigin(PlaceSuggestion origin, {bool recalculate = false}) {
    state = state.copyWith(origin: origin, preferredStopIds: const []);
    if (recalculate) calculateRoute();
  }

  /// Update arrival destination landmark.
  void setDestination(PlaceSuggestion dest, {bool recalculate = false}) {
    state = state.copyWith(destination: dest, preferredStopIds: const []);
    if (recalculate) calculateRoute();
  }

  /// Swap origin and destination endpoints.
  void swapOriginDestination({bool recalculate = false}) {
    final oldOrigin = state.origin;
    state = state.copyWith(
      origin: state.destination,
      destination: oldOrigin,
      preferredStopIds: const [],
    );
    if (recalculate) calculateRoute();
  }

  /// Update simulated battery State of Charge at departure.
  void setStartingSoc(int soc, {bool recalculate = false}) {
    state = state.copyWith(startingSocPercent: soc.clamp(10, 100));
    if (recalculate) calculateRoute();
  }

  /// Search places via repository.
  Future<List<PlaceSuggestion>> searchPlaces(String query) {
    return ref.read(routeRepositoryProvider).searchPlaces(query);
  }

  /// Apply one-click route preset for rapid demonstration or testing.
  void applyPreset({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required int startingSoc,
  }) {
    state = state.copyWith(
      origin: origin,
      destination: destination,
      startingSocPercent: startingSoc,
      preferredStopIds: const [],
    );
    calculateRoute();
  }

  /// Swap the charging stop station at stopIndex with a chosen vicinity alternative.
  Future<void> swapStopStation(int stopIndex, ChargingStation newStation) async {
    final currentPlan = state.currentPlan;
    if (currentPlan == null ||
        stopIndex < 0 ||
        stopIndex >= currentPlan.recommendedStops.length) {
      return;
    }

    final oldStop = currentPlan.recommendedStops[stopIndex];
    final activeVehicle = ref.read(vehicleControllerProvider).activeVehicle;

    final addedKwh = ((oldStop.departureSocPercent - oldStop.arrivalSocPercent) / 100.0) *
        activeVehicle.batteryCapacityKwh;
    final effectiveKw = min(newStation.maxPowerKw, activeVehicle.maxDcChargeKw);
    final chargeMins = max((addedKwh / (effectiveKw * 0.85) * 60).round(), 12);
    final costMyr = double.parse((addedKwh * newStation.chargingCostMyr).toStringAsFixed(2));

    final updatedAlternatives = <ChargingStation>[
      oldStop.station,
      ...oldStop.nearbyAlternatives.where((s) => s.id != newStation.id),
    ];

    double? cLat = oldStop.corridorLat;
    double? cLng = oldStop.corridorLng;
    if (currentPlan.polylinePoints.isNotEmpty) {
      final closest = currentPlan.polylinePoints.reduce((a, b) {
        final distA = pow(a.latitude - newStation.latitude, 2) +
            pow(a.longitude - newStation.longitude, 2);
        final distB = pow(b.latitude - newStation.latitude, 2) +
            pow(b.longitude - newStation.longitude, 2);
        return distA < distB ? a : b;
      });
      cLat = closest.latitude;
      cLng = closest.longitude;
    }

    final updatedStop = oldStop.copyWith(
      station: newStation,
      energyAddedKwh: double.parse(addedKwh.toStringAsFixed(1)),
      estimatedChargeMinutes: chargeMins,
      estimatedCostMyr: costMyr,
      corridorLat: cLat,
      corridorLng: cLng,
      nearbyAlternatives: updatedAlternatives,
    );

    final updatedStops = List<ChargingStopRecommendation>.from(currentPlan.recommendedStops);
    updatedStops[stopIndex] = updatedStop;

    final totalChargeMins = updatedStops.fold<int>(0, (sum, s) => sum + s.estimatedChargeMinutes);
    final updatedPlan = currentPlan.copyWith(
      recommendedStops: updatedStops,
      totalChargingMinutes: totalChargeMins,
      totalTripMinutes: currentPlan.estimatedDriveMinutes + totalChargeMins,
    );

    final updatedPreferred = List<String>.from(state.preferredStopIds)
      ..remove(oldStop.station.id)
      ..add(newStation.id);

    state = state.copyWith(
      currentPlan: updatedPlan,
      preferredStopIds: updatedPreferred,
    );
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
        preferredStopStationIds: state.preferredStopIds,
      );

      if (_disposed) return;
      state = state.copyWith(
        currentPlan: plan,
        isLoading: false,
      );
    } catch (e) {
      if (_disposed) return;
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
