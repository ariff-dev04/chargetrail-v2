import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/station_local_cache.dart';
import '../data/station_repository.dart';
import '../domain/station_model.dart';

/// State representation for station discovery, filters, and offline status.
class StationState {
  final List<ChargingStation> allStations;
  final List<ChargingStation> filteredStations;
  final StationFilter activeFilter;
  final ChargingStation? selectedStation;
  final bool isLoading;
  final bool isOfflineMode;
  final String? errorMessage;

  const StationState({
    this.allStations = const [],
    this.filteredStations = const [],
    this.activeFilter = const StationFilter(),
    this.selectedStation,
    this.isLoading = false,
    this.isOfflineMode = false,
    this.errorMessage,
  });

  StationState copyWith({
    List<ChargingStation>? allStations,
    List<ChargingStation>? filteredStations,
    StationFilter? activeFilter,
    ChargingStation? selectedStation,
    bool clearSelectedStation = false,
    bool? isLoading,
    bool? isOfflineMode,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return StationState(
      allStations: allStations ?? this.allStations,
      filteredStations: filteredStations ?? this.filteredStations,
      activeFilter: activeFilter ?? this.activeFilter,
      selectedStation: clearSelectedStation
          ? null
          : (selectedStation ?? this.selectedStation),
      isLoading: isLoading ?? this.isLoading,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Dependency provider for StationRepository
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository();
});

/// Riverpod controller orchestrating station fetching, filtering, and detail selection.
class StationNotifier extends Notifier<StationState> {
  @override
  StationState build() {
    // Provide instant local Malaysian baseline while async load completes
    final initialBaseline = StationLocalCache.defaultMalaysianStations();
    state = StationState(
      allStations: initialBaseline,
      filteredStations: initialBaseline,
      isLoading: true,
      isOfflineMode: false,
    );

    // Trigger asynchronous remote fetch or cache sync
    Future.microtask(() => loadStations());

    return state;
  }

  /// Fetch stations from remote API or fallback cache.
  Future<void> loadStations() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final repository = ref.read(stationRepositoryProvider);
      final result = await repository.fetchStations();

      final filtered =
          result.stations.where(state.activeFilter.matches).toList();

      state = state.copyWith(
        allStations: result.stations,
        filteredStations: filtered,
        isLoading: false,
        isOfflineMode: result.isOffline,
      );
    } catch (e) {
      final fallback = StationLocalCache.defaultMalaysianStations();
      state = state.copyWith(
        allStations: fallback,
        filteredStations: fallback.where(state.activeFilter.matches).toList(),
        isLoading: false,
        isOfflineMode: true,
        errorMessage: 'Operating in offline fallback mode.',
      );
    }
  }

  /// Apply arbitrary filter updates and re-evaluate visible stations.
  void updateFilter(StationFilter newFilter) {
    final filtered = state.allStations.where(newFilter.matches).toList();
    state = state.copyWith(
      activeFilter: newFilter,
      filteredStations: filtered,
    );
  }

  /// Toggle connector type filter (e.g. CCS2, Type 2, CHAdeMO).
  void toggleConnector(String type) {
    final current = state.activeFilter.connectorType;
    final updated = current == type
        ? state.activeFilter.copyWith(clearConnectorType: true)
        : state.activeFilter.copyWith(connectorType: type);
    updateFilter(updated);
  }

  /// Toggle minimum power output filter in kW.
  void toggleMinKw(double kw) {
    final current = state.activeFilter.minKw;
    final updated = current == kw
        ? state.activeFilter.copyWith(clearMinKw: true)
        : state.activeFilter.copyWith(minKw: kw);
    updateFilter(updated);
  }

  /// Toggle 24-hour access filter.
  void toggle24Hours() {
    final current = state.activeFilter.only24Hours;
    updateFilter(state.activeFilter.copyWith(only24Hours: !current));
  }

  /// Toggle amenity tag filter.
  void toggleAmenity(String amenity) {
    final current = state.activeFilter.amenity;
    final updated = current == amenity
        ? state.activeFilter.copyWith(clearAmenity: true)
        : state.activeFilter.copyWith(amenity: amenity);
    updateFilter(updated);
  }

  /// Update query text for instantaneous station name/operator search.
  void setSearchQuery(String query) {
    final updated = query.trim().isEmpty
        ? state.activeFilter.copyWith(clearSearchQuery: true)
        : state.activeFilter.copyWith(searchQuery: query);
    updateFilter(updated);
  }

  /// Clear all active filters back to baseline unfiltered view.
  void resetFilters() {
    updateFilter(const StationFilter());
  }

  /// Select a station to focus map or open detail inspection bottom sheet.
  void selectStation(ChargingStation? station) {
    state = state.copyWith(
      selectedStation: station,
      clearSelectedStation: station == null,
    );
  }
}

/// Global provider for StationController
final stationControllerProvider =
    NotifierProvider<StationNotifier, StationState>(StationNotifier.new);
