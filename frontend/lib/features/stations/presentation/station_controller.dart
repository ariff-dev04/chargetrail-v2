import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/osm_overpass_service.dart';
import '../data/station_local_cache.dart';
import '../data/station_repository.dart';
import '../domain/station_model.dart';

/// State representation for station discovery, filters, and offline status.
class StationState {
  final List<ChargingStation> allStations;
  final List<ChargingStation> filteredStations;
  final StationFilter activeFilter;
  final ChargingStation? selectedStation;
  final double referenceLat;
  final double referenceLng;
  final bool isLoading;
  final bool isOfflineMode;
  final String? errorMessage;

  const StationState({
    this.allStations = const [],
    this.filteredStations = const [],
    this.activeFilter = const StationFilter(),
    this.selectedStation,
    this.referenceLat = 3.1578,
    this.referenceLng = 101.7118,
    this.isLoading = false,
    this.isOfflineMode = false,
    this.errorMessage,
  });

  /// Stations sorted by ascending distance relative to active reference coordinates (GPS or map center).
  List<ChargingStation> get nearbyStations {
    final list = [...filteredStations];
    list.sort((a, b) {
      final da = distanceKmTo(a.latitude, a.longitude);
      final db = distanceKmTo(b.latitude, b.longitude);
      return da.compareTo(db);
    });
    return list;
  }

  /// Compute Euclidean/Haversine distance (km) to given target coordinates.
  double distanceKmTo(double lat, double lng) {
    final dLat = (lat - referenceLat) * 111.0;
    final dLon = (lng - referenceLng) * 111.0 * cos(referenceLat * pi / 180.0);
    return sqrt(dLat * dLat + dLon * dLon);
  }

  StationState copyWith({
    List<ChargingStation>? allStations,
    List<ChargingStation>? filteredStations,
    StationFilter? activeFilter,
    ChargingStation? selectedStation,
    bool clearSelectedStation = false,
    double? referenceLat,
    double? referenceLng,
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
      referenceLat: referenceLat ?? this.referenceLat,
      referenceLng: referenceLng ?? this.referenceLng,
      isLoading: isLoading ?? this.isLoading,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Dependency provider for StationRepository.
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository();
});

/// Riverpod controller managing station search, filters, and selection state.
class StationNotifier extends Notifier<StationState> {
  @override
  StationState build() {
    state = const StationState(isLoading: true);
    Future.microtask(() => loadStations());
    return state;
  }

  /// Asynchronously retrieve charging stations from repository or cache.
  Future<void> loadStations({
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repository = ref.read(stationRepositoryProvider);
      final result = await repository.fetchStations(
        minLat: minLat,
        minLng: minLng,
        maxLat: maxLat,
        maxLng: maxLng,
      );

      final filtered = result.stations.where(state.activeFilter.matches).toList();
      state = state.copyWith(
        allStations: result.stations,
        filteredStations: filtered,
        isLoading: false,
        isOfflineMode: result.isOffline,
      );

      if (result.stations.isEmpty && !result.isOffline) {
        scanOsmViewport(
          centerLat: state.referenceLat,
          centerLng: state.referenceLng,
          minLat: minLat ?? (state.referenceLat - 0.15),
          minLng: minLng ?? (state.referenceLng - 0.15),
          maxLat: maxLat ?? (state.referenceLat + 0.15),
          maxLng: maxLng ?? (state.referenceLng + 0.15),
        );
      }
    } catch (e) {
      final cached = await StationLocalCache().getCachedStations();
      final filtered = cached.where(state.activeFilter.matches).toList();
      state = state.copyWith(
        allStations: cached,
        filteredStations: filtered,
        isLoading: false,
        isOfflineMode: true,
        errorMessage: 'Failed to retrieve stations: $e',
      );
    }
  }

  /// Update reference coordinates for sorting nearby stations.
  void updateReferenceLocation(double lat, double lng) {
    state = state.copyWith(referenceLat: lat, referenceLng: lng);
  }

  /// Apply keyword text search against station name, address, and city.
  void setSearchQuery(String query) {
    final updatedFilter = state.activeFilter.copyWith(searchQuery: query);
    _applyFilter(updatedFilter);
  }

  /// Toggle connector type filter chip (e.g., CCS2, Type 2, CHAdeMO).
  void toggleConnector(String type) {
    final current = state.activeFilter.connectorType;
    final updated = current == type
        ? state.activeFilter.copyWith(clearConnectorType: true)
        : state.activeFilter.copyWith(connectorType: type);
    _applyFilter(updated);
  }

  /// Toggle minimum power output threshold (e.g., 120kW+ Fast DC).
  void toggleMinKw(double minKw) {
    final current = state.activeFilter.minKw;
    final updated = current == minKw
        ? state.activeFilter.copyWith(clearMinKw: true)
        : state.activeFilter.copyWith(minKw: minKw);
    _applyFilter(updated);
  }

  /// Toggle 24/7 operating hour filter.
  void toggle24Hours() {
    final updated = state.activeFilter.copyWith(
      only24Hours: !state.activeFilter.only24Hours,
    );
    _applyFilter(updated);
  }

  /// Toggle amenity requirement (e.g., Dining, Restroom).
  void toggleAmenity(String amenity) {
    final current = state.activeFilter.amenity;
    final updated = current == amenity
        ? state.activeFilter.copyWith(clearAmenity: true)
        : state.activeFilter.copyWith(amenity: amenity);
    _applyFilter(updated);
  }

  /// Reset all active filters to default empty state.
  void resetFilters() {
    _applyFilter(const StationFilter());
  }

  void _applyFilter(StationFilter filter) {
    final filtered = state.allStations.where(filter.matches).toList();
    state = state.copyWith(
      activeFilter: filter,
      filteredStations: filtered,
    );
  }

  /// Select a station to focus map or open detail inspection bottom sheet.
  void selectStation(ChargingStation? station) {
    state = state.copyWith(
      selectedStation: station,
      clearSelectedStation: station == null,
    );

    // On-interaction upsert: if user inspects an external OSM or open data station, persist it to DB & cache
    if (station != null && (station.source == 'osm_live' || station.source == 'open_data_my')) {
      ref.read(stationRepositoryProvider).upsertExternalStation(station);
    }
  }

  /// Multi-source lazy discovery of live OSM and open data charging stations in viewport.
  Future<int> scanOsmViewport({
    required double centerLat,
    required double centerLng,
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    try {
      final overpass = OsmOverpassService();
      final discovered = await overpass.fetchStationsInBounds(
        centerLat: centerLat,
        centerLng: centerLng,
        minLat: minLat,
        minLng: minLng,
        maxLat: maxLat,
        maxLng: maxLng,
        existingStations: state.allStations,
      );

      if (discovered.isNotEmpty) {
        ref.read(stationRepositoryProvider).upsertBatch(discovered);
        final merged = [...state.allStations, ...discovered];
        final filtered = merged.where(state.activeFilter.matches).toList();
        state = state.copyWith(
          allStations: merged,
          filteredStations: filtered,
        );
        return discovered.length;
      }
    } catch (_) {}
    return 0;
  }
}

/// Global provider for StationController
final stationControllerProvider =
    NotifierProvider<StationNotifier, StationState>(StationNotifier.new);
