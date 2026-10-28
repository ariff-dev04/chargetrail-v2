import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_service.dart';
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
  final double? userLat;
  final double? userLng;
  final bool isLoading;
  final bool isOfflineMode;
  final String? errorMessage;

  const StationState({
    this.allStations = const [],
    this.filteredStations = const [],
    this.activeFilter = const StationFilter(),
    this.selectedStation,
    this.referenceLat = 4.2105,
    this.referenceLng = 101.9758,
    this.userLat,
    this.userLng,
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
    double? userLat,
    bool clearUserLat = false,
    double? userLng,
    bool clearUserLng = false,
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
      userLat: clearUserLat ? null : (userLat ?? this.userLat),
      userLng: clearUserLng ? null : (userLng ?? this.userLng),
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
    Future.microtask(() => _initializeWithGps());
    return state;
  }

  /// Acquire real device GPS first, then load and harvest viewport stations.
  Future<void> _initializeWithGps() async {
    double? realLat;
    double? realLng;

    try {
      final loc = await LocationService().determinePosition();
      if (loc.latitude >= -90.0 &&
          loc.latitude <= 90.0 &&
          loc.longitude >= -180.0 &&
          loc.longitude <= 180.0) {
        realLat = loc.latitude;
        realLng = loc.longitude;
      }
    } catch (_) {}

    if (realLat != null && realLng != null) {
      state = state.copyWith(
        userLat: realLat,
        userLng: realLng,
        referenceLat: realLat,
        referenceLng: realLng,
      );

      const delta = 0.15;
      await loadStations(
        minLat: realLat - delta,
        minLng: realLng - delta,
        maxLat: realLat + delta,
        maxLng: realLng + delta,
      );

      scanOsmViewport(
        centerLat: realLat,
        centerLng: realLng,
        minLat: realLat - delta,
        minLng: realLng - delta,
        maxLat: realLat + delta,
        maxLng: realLng + delta,
      );
    } else {
      // If GPS is still resolving or fails, do not load a 500km country-wide box.
      // Retain genuine cached stations if previously stored.
      final cached = await StationLocalCache().getCachedStations();
      final filtered = cached.where(state.activeFilter.matches).toList();
      state = state.copyWith(
        allStations: cached,
        filteredStations: filtered,
        isLoading: false,
      );
    }
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

      final cLat = (minLat != null && maxLat != null) ? (minLat + maxLat) / 2.0 : state.referenceLat;
      final cLng = (minLng != null && maxLng != null) ? (minLng + maxLng) / 2.0 : state.referenceLng;

      // Keep newly discovered stations plus existing stations within relevant regional proximity (~60km)
      final regionalStations = <ChargingStation>[...result.stations];
      for (final s in state.allStations) {
        if (!regionalStations.any((r) => r.id == s.id)) {
          final dLat = (s.latitude - cLat).abs();
          final dLon = (s.longitude - cLng).abs();
          if (dLat <= 0.65 && dLon <= 0.65) {
            regionalStations.add(s);
          }
        }
      }

      final filtered = regionalStations.where(state.activeFilter.matches).toList();
      state = state.copyWith(
        allStations: regionalStations,
        filteredStations: filtered,
        isLoading: false,
        isOfflineMode: result.isOffline,
      );

      if (!result.isOffline) {
        scanOsmViewport(
          centerLat: cLat,
          centerLng: cLng,
          minLat: minLat ?? (cLat - 0.15),
          minLng: minLng ?? (cLng - 0.15),
          maxLat: maxLat ?? (cLat + 0.15),
          maxLng: maxLng ?? (cLng + 0.15),
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

  /// Update user GPS coordinates and reference location.
  void updateUserLocation(double lat, double lng) {
    state = state.copyWith(
      userLat: lat,
      userLng: lng,
      referenceLat: lat,
      referenceLng: lng,
    );
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
  void selectStation(ChargingStation? station) async {
    state = state.copyWith(
      selectedStation: station,
      clearSelectedStation: station == null,
    );

    // On-interaction upsert: if user inspects an external OSM or open data station, persist it to DB & cache
    if (station != null && (station.source == 'osm_live' || station.source == 'open_data_my')) {
      final repository = ref.read(stationRepositoryProvider);
      final savedStation = await repository.upsertExternalStation(station);
      final updatedStations = state.allStations.map((s) {
        return (s.id == station.id ||
                (s.latitude == station.latitude && s.longitude == station.longitude))
            ? savedStation
            : s;
      }).toList();

      final filtered = updatedStations.where(state.activeFilter.matches).toList();
      state = state.copyWith(
        allStations: updatedStations,
        filteredStations: filtered,
        selectedStation:
            state.selectedStation?.id == station.id ? savedStation : state.selectedStation,
      );
      await StationLocalCache().saveStations(updatedStations);
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
    bool forceRefresh = false,
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
        forceRefresh: forceRefresh,
      );

      if (discovered.isNotEmpty) {
        // Keep newly discovered viewport stations in state with source: 'osm_live' without auto-upserting to DB
        final toAdd = <ChargingStation>[];
        for (final d in discovered) {
          final isNear = state.allStations.any((s) {
            final dLat = (s.latitude - d.latitude) * 111.0;
            final dLon = (s.longitude - d.longitude) * 111.0 * cos(d.latitude * pi / 180.0);
            return sqrt(dLat * dLat + dLon * dLon) < 0.15;
          });
          if (!isNear) {
            toAdd.add(d);
          }
        }

        if (toAdd.isNotEmpty) {
          final merged = [...state.allStations, ...toAdd];
          // Filter to stations relevant to the current map region (~60km / 0.65 deg) so list remains focused
          final relevant = merged.where((s) {
            final dLat = (s.latitude - centerLat).abs();
            final dLon = (s.longitude - centerLng).abs();
            return dLat <= 0.65 && dLon <= 0.65;
          }).toList();

          final filtered = relevant.where(state.activeFilter.matches).toList();
          state = state.copyWith(
            allStations: relevant,
            filteredStations: filtered,
          );
          return toAdd.length;
        }
      }
    } catch (_) {}
    return 0;
  }
}

/// Global provider for StationController
final stationControllerProvider =
    NotifierProvider<StationNotifier, StationState>(StationNotifier.new);
