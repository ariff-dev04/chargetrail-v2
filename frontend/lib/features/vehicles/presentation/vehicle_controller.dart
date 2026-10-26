import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle_model.dart';

/// State representation for garage vehicles, active EV selection, and SoC simulation.
class VehicleState {
  final List<VehicleProfile> garageVehicles;
  final List<VehicleProfile> presets;
  final int simulatedCurrentSoc;
  final bool isLoading;
  final String? errorMessage;

  const VehicleState({
    this.garageVehicles = const [],
    this.presets = const [],
    this.simulatedCurrentSoc = 80,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Current primary vehicle used for route simulation and charge estimations.
  VehicleProfile get activeVehicle {
    if (garageVehicles.isEmpty) {
      return VehicleRepository.defaultPresets.first;
    }
    return garageVehicles.firstWhere(
      (v) => v.isPrimary,
      orElse: () => garageVehicles.first,
    );
  }

  VehicleState copyWith({
    List<VehicleProfile>? garageVehicles,
    List<VehicleProfile>? presets,
    int? simulatedCurrentSoc,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VehicleState(
      garageVehicles: garageVehicles ?? this.garageVehicles,
      presets: presets ?? this.presets,
      simulatedCurrentSoc: simulatedCurrentSoc ?? this.simulatedCurrentSoc,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Dependency provider for VehicleRepository.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

/// Riverpod controller managing user's multi-vehicle garage and active EV telemetry.
class VehicleNotifier extends Notifier<VehicleState> {
  @override
  VehicleState build() {
    final presets = VehicleRepository.defaultPresets;
    final initialGarage = [
      presets[0].copyWith(id: 'garage-v1', isPrimary: true, nickname: 'My Daily e.MAS 7'),
      presets[1].copyWith(id: 'garage-v2', isPrimary: false, nickname: 'Family Atto 3'),
    ];

    state = VehicleState(
      garageVehicles: initialGarage,
      presets: presets,
      simulatedCurrentSoc: 80,
      isLoading: true,
    );

    Future.microtask(() => loadVehicles());
    return state;
  }

  /// Fetch vehicles from API or local cache.
  Future<void> loadVehicles() async {
    final repo = ref.read(vehicleRepositoryProvider);
    final vehicles = await repo.fetchVehicles();
    state = state.copyWith(
      garageVehicles: vehicles,
      isLoading: false,
    );
  }

  /// Update simulated battery State of Charge percentage (10% - 100%).
  void setSimulatedSoc(int soc) {
    state = state.copyWith(simulatedCurrentSoc: soc.clamp(5, 100));
  }

  /// Add vehicle to garage by selecting from Malaysian preset catalog.
  Future<void> addVehicleFromPreset(VehicleProfile preset, {String? customNickname}) async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(vehicleRepositoryProvider);
    final toAdd = preset.copyWith(
      id: '',
      nickname: customNickname ?? preset.displayName,
      isPrimary: state.garageVehicles.isEmpty,
    );
    await repo.addVehicle(toAdd);
    await loadVehicles();
  }

  /// Set selected vehicle as primary active EV for battery-aware routing.
  Future<void> setPrimaryVehicle(String vehicleId) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.setPrimary(vehicleId);
    await loadVehicles();
  }

  /// Update safety reserve buffer percentage on vehicle.
  Future<void> updateReserveSoc(String vehicleId, int newReservePercent) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final vehicle = state.garageVehicles.firstWhere((v) => v.id == vehicleId);
    final updated = vehicle.copyWith(reserveSocPercent: newReservePercent.clamp(5, 40));
    await repo.updateVehicle(updated);
    await loadVehicles();
  }

  /// Delete EV from user's garage.
  Future<void> deleteVehicle(String vehicleId) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.deleteVehicle(vehicleId);
    await loadVehicles();
  }
}

/// Global provider for VehicleController.
final vehicleControllerProvider =
    NotifierProvider<VehicleNotifier, VehicleState>(VehicleNotifier.new);
