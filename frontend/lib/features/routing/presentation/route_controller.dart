import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/domain/station_model.dart';
import '../../vehicles/presentation/vehicle_controller.dart';
import '../data/route_repository.dart';
import '../domain/route_models.dart';

typedef RoutePlannerState = RouteState;

/// State representation for journey route planning and battery simulation.
class RouteState {
  final PlaceSuggestion? selectedOrigin;
  final PlaceSuggestion? selectedDestination;
  final int startingSocPercent;
  final RoutePlanResult? currentPlan;
  final List<String> preferredStopIds;
  final bool isLoading;
  final String? errorMessage;
  final String stopStrategy; // few_long, quickest, short_many
  final double targetArrivalSocPct;
  final bool preferEasyAccess;
  final bool isMoreOptionsExpanded;

  const RouteState({
    PlaceSuggestion? selectedOrigin,
    PlaceSuggestion? selectedDestination,
    PlaceSuggestion? origin,
    PlaceSuggestion? destination,
    this.startingSocPercent = 55,
    this.currentPlan,
    this.preferredStopIds = const [],
    this.isLoading = false,
    this.errorMessage,
    this.stopStrategy = 'quickest',
    this.targetArrivalSocPct = 20.0,
    this.preferEasyAccess = true,
    this.isMoreOptionsExpanded = false,
  })  : selectedOrigin = selectedOrigin ?? origin,
        selectedDestination = selectedDestination ?? destination;

  /// Convenient accessor returning selectedOrigin or an empty PlaceSuggestion placeholder.
  PlaceSuggestion get origin =>
      selectedOrigin ?? const PlaceSuggestion(name: '', city: '', state: '', latitude: 0.0, longitude: 0.0);

  /// Convenient accessor returning selectedDestination or an empty PlaceSuggestion placeholder.
  PlaceSuggestion get destination =>
      selectedDestination ?? const PlaceSuggestion(name: '', city: '', state: '', latitude: 0.0, longitude: 0.0);

  bool get hasValidEndpoints =>
      selectedOrigin != null &&
      selectedOrigin!.name.isNotEmpty &&
      selectedDestination != null &&
      selectedDestination!.name.isNotEmpty;

  RouteState copyWith({
    PlaceSuggestion? selectedOrigin,
    bool clearSelectedOrigin = false,
    PlaceSuggestion? selectedDestination,
    bool clearSelectedDestination = false,
    PlaceSuggestion? origin,
    PlaceSuggestion? destination,
    int? startingSocPercent,
    RoutePlanResult? currentPlan,
    bool clearCurrentPlan = false,
    List<String>? preferredStopIds,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? stopStrategy,
    double? targetArrivalSocPct,
    bool? preferEasyAccess,
    bool? isMoreOptionsExpanded,
  }) {
    final newOrigin = clearSelectedOrigin ? null : (selectedOrigin ?? origin ?? this.selectedOrigin);
    final newDestination = clearSelectedDestination ? null : (selectedDestination ?? destination ?? this.selectedDestination);

    return RouteState(
      selectedOrigin: newOrigin,
      selectedDestination: newDestination,
      startingSocPercent: startingSocPercent ?? this.startingSocPercent,
      currentPlan: clearCurrentPlan ? null : (currentPlan ?? this.currentPlan),
      preferredStopIds: preferredStopIds ?? this.preferredStopIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      stopStrategy: stopStrategy ?? this.stopStrategy,
      targetArrivalSocPct: targetArrivalSocPct ?? this.targetArrivalSocPct,
      preferEasyAccess: preferEasyAccess ?? this.preferEasyAccess,
      isMoreOptionsExpanded: isMoreOptionsExpanded ?? this.isMoreOptionsExpanded,
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

    state = const RouteState(
      selectedOrigin: null,
      selectedDestination: null,
      startingSocPercent: 55,
      currentPlan: null,
      isLoading: false,
    );

    ref.listen<VehicleState>(vehicleControllerProvider, (prev, next) {
      if (prev?.activeVehicle.id != next.activeVehicle.id ||
          prev?.activeVehicle.batteryCapacityKwh != next.activeVehicle.batteryCapacityKwh ||
          prev?.activeVehicle.efficiencyWhPerKm != next.activeVehicle.efficiencyWhPerKm ||
          prev?.activeVehicle.maxDcChargeKw != next.activeVehicle.maxDcChargeKw) {
        if (state.hasValidEndpoints) {
          calculateRoute();
        }
      }
    });

    return state;
  }

  /// Update departure origin landmark.
  void setOrigin(PlaceSuggestion origin, {bool recalculate = false}) {
    state = state.copyWith(
      selectedOrigin: origin,
      clearSelectedOrigin: origin.name.isEmpty,
      preferredStopIds: const [],
    );
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Update arrival destination landmark.
  void setDestination(PlaceSuggestion dest, {bool recalculate = false}) {
    state = state.copyWith(
      selectedDestination: dest,
      clearSelectedDestination: dest.name.isEmpty,
      preferredStopIds: const [],
    );
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Swap origin and destination endpoints.
  void swapOriginDestination({bool recalculate = false}) {
    final oldOrigin = state.selectedOrigin;
    final oldDest = state.selectedDestination;
    state = state.copyWith(
      selectedOrigin: oldDest,
      selectedDestination: oldOrigin,
      clearSelectedOrigin: oldDest == null,
      clearSelectedDestination: oldOrigin == null,
      preferredStopIds: const [],
    );
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Update simulated battery State of Charge at departure.
  void setStartingSoc(int soc, {bool recalculate = false}) {
    state = state.copyWith(startingSocPercent: soc.clamp(10, 100));
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Update charging stop strategy (few_long, quickest, short_many).
  void setStopStrategy(String strategy, {bool recalculate = false}) {
    state = state.copyWith(stopStrategy: strategy);
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Update desired arrival buffer SoC percentage at final destination.
  void setTargetArrivalSoc(double val, {bool recalculate = false}) {
    state = state.copyWith(targetArrivalSocPct: val.clamp(5.0, 50.0));
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Toggle easy-access preference (Highway R&R and open public bays over indoor carparks).
  void togglePreferEasyAccess(bool val, {bool recalculate = false}) {
    state = state.copyWith(preferEasyAccess: val);
    if (recalculate && state.hasValidEndpoints) {
      calculateRoute();
    }
  }

  /// Toggle expansion of advanced strategy and vehicle configuration options.
  void toggleMoreOptions() {
    state = state.copyWith(isMoreOptionsExpanded: !state.isMoreOptionsExpanded);
  }

  /// Reset origin, destination, and active route plan (e.g. Clear / Restart button).
  void clearRouteInputs() {
    state = state.copyWith(
      clearSelectedOrigin: true,
      clearSelectedDestination: true,
      clearCurrentPlan: true,
      clearErrorMessage: true,
      preferredStopIds: const [],
      isLoading: false,
    );
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
      selectedOrigin: origin,
      selectedDestination: destination,
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
    if (!state.hasValidEndpoints) {
      state = state.copyWith(isLoading: false, clearCurrentPlan: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repo = ref.read(routeRepositoryProvider);
      final activeVehicle = ref.read(vehicleControllerProvider).activeVehicle;

      final plan = await repo.calculateRoutePlan(
        origin: state.selectedOrigin!,
        destination: state.selectedDestination!,
        vehicle: activeVehicle,
        startingSocPercent: state.startingSocPercent,
        preferredStopStationIds: state.preferredStopIds,
        stopStrategy: state.stopStrategy,
        targetArrivalSocPct: state.targetArrivalSocPct,
        preferEasyAccess: state.preferEasyAccess,
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
