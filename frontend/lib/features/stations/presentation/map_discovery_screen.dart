import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/map_tile_config.dart';
import 'package:frontend/core/services/location_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';
import '../../community/presentation/submit_station_sheet.dart';
import 'station_controller.dart';
import 'widgets/nearby_stations_carousel.dart';
import 'widgets/station_detail_sheet.dart';
import 'widgets/station_filter_bar.dart';

/// Main EV Charging Station map discovery view with live sync, GPS, and nearby carousel.
class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen> {
  final MapController _mapController = MapController();
  static const LatLng _kDefaultCenter = LatLng(4.2105, 101.9758);
  static const double _kDefaultZoom = 6.5;
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stState = ref.read(stationControllerProvider);
      if (!_hasCenteredOnUser && stState.userLat != null && stState.userLng != null) {
        _hasCenteredOnUser = true;
        _centerMap(LatLng(stState.userLat!, stState.userLng!), 14.0);
      }
    });
  }

  void _centerMap(LatLng target, [double zoom = 14.0]) => _mapController.move(target, zoom);

  Future<void> _handleMyLocation() async {
    final loc = await LocationService().determinePosition();
    ref.read(userLocationProvider.notifier).setLocation(loc);
    ref.read(stationControllerProvider.notifier).updateUserLocation(loc.latitude, loc.longitude);
    _centerMap(loc.latLng, 14.0);

    // Auto-discover nearby open EV chargers around physical GPS
    ref.read(stationControllerProvider.notifier).scanOsmViewport(
          centerLat: loc.latitude,
          centerLng: loc.longitude,
          minLat: loc.latitude - 0.08,
          minLng: loc.longitude - 0.08,
          maxLat: loc.latitude + 0.08,
          maxLng: loc.longitude + 0.08,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS Locked: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (${loc.label})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleScanOsmViewport() async {
    final center = _mapController.camera.center;
    final bounds = _mapController.camera.visibleBounds;
    ref.read(stationControllerProvider.notifier).updateReferenceLocation(center.latitude, center.longitude);

    final count = await ref.read(stationControllerProvider.notifier).scanOsmViewport(
          centerLat: center.latitude,
          centerLng: center.longitude,
          minLat: bounds.southWest.latitude,
          minLng: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLng: bounds.northEast.longitude,
          forceRefresh: true,
        );

    if (mounted) {
      final total = ref.read(stationControllerProvider).nearbyStations.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '⚡ Discovered +$count chargers in this area ($total nearby) • Tap any pin to save to DB'
                : 'Viewport is up to date ($total nearby chargers)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationControllerProvider);
    final notifier = ref.read(stationControllerProvider.notifier);
    final mapStyle = ref.watch(mapTileStyleProvider);
    final userLoc = ref.watch(userLocationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<StationState>(stationControllerProvider, (previous, next) {
      if (!_hasCenteredOnUser && next.userLat != null && next.userLng != null) {
        _hasCenteredOnUser = true;
        final target = LatLng(next.userLat!, next.userLng!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _centerMap(target, 14.0);
            notifier.scanOsmViewport(
              centerLat: target.latitude,
              centerLng: target.longitude,
              minLat: target.latitude - 0.08,
              minLng: target.longitude - 0.08,
              maxLat: target.latitude + 0.08,
              maxLng: target.longitude + 0.08,
            );
          }
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kDefaultCenter,
              initialZoom: _kDefaultZoom,
              minZoom: 5.0,
              maxZoom: 18.0,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  final center = _mapController.camera.center;
                  final bounds = _mapController.camera.visibleBounds;
                  ref.read(stationControllerProvider.notifier).updateReferenceLocation(center.latitude, center.longitude);
                  ref.read(stationControllerProvider.notifier).scanOsmViewport(
                        centerLat: center.latitude,
                        centerLng: center.longitude,
                        minLat: bounds.southWest.latitude,
                        minLng: bounds.southWest.longitude,
                        maxLat: bounds.northEast.latitude,
                        maxLng: bounds.northEast.longitude,
                      );
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: mapStyle.urlTemplate, userAgentPackageName: 'my.ukm.chargetrail.v2'),
              MarkerLayer(
                markers: [
                  if (userLoc != null)
                    Marker(point: userLoc.latLng, width: 34, height: 34, child: const UserLocationMarkerWidget()),
                  ...state.filteredStations.map((station) {
                    final isSelected = state.selectedStation?.id == station.id;
                    final isOpenData = station.source == 'osm_live' || station.source == 'open_data_my';

                    return Marker(
                      point: LatLng(station.latitude, station.longitude),
                      width: isSelected ? 48 : 40,
                      height: isSelected ? 48 : 40,
                      child: GestureDetector(
                        onTap: () {
                          notifier.selectStation(station);
                          StationDetailSheet.show(context, station);
                        },
                        child: _markerIcon(station.maxPowerKw >= 120.0, isSelected, isOpenData),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Top Floating Filter Bar Overlay, Style Switcher & OSM Viewport Scanner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isOfflineMode)
                      GestureDetector(
                        onTap: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Checking live backend connectivity...'), duration: Duration(milliseconds: 800)),
                          );
                          await notifier.loadStations();
                          if (!context.mounted) return;
                          final updated = ref.read(stationControllerProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                !updated.isOfflineMode
                                    ? '✅ Connected to Live FastAPI Server (${updated.allStations.length} stations synced)'
                                    : '⚠️ Live backend unreachable — serving ${updated.allStations.length} stations from Local Cache',
                              ),
                              backgroundColor: !updated.isOfflineMode ? AppTheme.successGreen : const Color(0xFFD97706),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.cloud_off, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Offline Mode • Tap to Reconnect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ]),
                        ),
                      ),
                    StationFilterBar(
                      activeFilter: state.activeFilter,
                      onSearchChanged: notifier.setSearchQuery,
                      onToggleConnector: notifier.toggleConnector,
                      onToggleMinKw: notifier.toggleMinKw,
                      onToggle24Hours: notifier.toggle24Hours,
                      onToggleAmenity: notifier.toggleAmenity,
                      onReset: notifier.resetFilters,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: _handleScanOsmViewport,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.travel_explore, size: 14, color: AppTheme.primaryTeal),
                              SizedBox(width: 5),
                              Text('Scan Viewport OSM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        const MapStyleSelectorButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Bottom Controls: Nearby Chargers Carousel, Counter, Add & GPS
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nearby Chargers Horizontal Carousel
                NearbyStationsCarousel(
                  stations: state.nearbyStations,
                  distanceCalculator: (lat, lng) => state.distanceKmTo(lat, lng),
                  onStationTap: (station) {
                    notifier.selectStation(station);
                    _centerMap(LatLng(station.latitude, station.longitude), 15.0);
                    StationDetailSheet.show(context, station);
                  },
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.ev_station, size: 15, color: AppTheme.primaryTeal),
                          const SizedBox(width: 4),
                          Text('${state.filteredStations.length} in view', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.extended(
                            heroTag: 'add_station_fab',
                            onPressed: () => SubmitStationSheet.show(
                              context,
                              initialLatitude: userLoc?.latitude ?? _kDefaultCenter.latitude,
                              initialLongitude: userLoc?.longitude ?? _kDefaultCenter.longitude,
                            ),
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            icon: const Icon(Icons.add_location_alt, size: 15),
                            label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          FloatingActionButton.small(
                            heroTag: 'my_location_fab',
                            onPressed: _handleMyLocation,
                            backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                            foregroundColor: AppTheme.primaryTeal,
                            child: const Icon(Icons.my_location, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _markerIcon(bool isUltraFast, bool isSelected, bool isOpenData) {
    final color = isOpenData ? const Color(0xFF0284C7) : (isUltraFast ? AppTheme.ultraFastColor : AppTheme.primaryTeal);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? Colors.amber : Colors.white, width: isSelected ? 3.0 : 1.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)],
      ),
      child: Center(
        child: Icon(isUltraFast ? Icons.bolt : (isOpenData ? Icons.public : Icons.ev_station), color: Colors.white, size: isSelected ? 24 : 20),
      ),
    );
  }
}
