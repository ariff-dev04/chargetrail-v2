import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/map_tile_config.dart';
import 'package:frontend/core/services/location_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';
import '../../community/presentation/submit_station_sheet.dart';
import '../domain/station_model.dart';
import 'station_controller.dart';
import 'widgets/station_detail_sheet.dart';
import 'widgets/station_filter_bar.dart';

/// Main EV Charging Station map discovery view with map styles, GPS, and OSM viewport discovery.
class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen> {
  final MapController _mapController = MapController();
  static const LatLng _kDefaultCenter = LatLng(3.1578, 101.7118);

  void _centerMap(LatLng target, [double zoom = 14.0]) => _mapController.move(target, zoom);

  Future<void> _handleMyLocation() async {
    final loc = await LocationService().determinePosition();
    ref.read(userLocationProvider.notifier).setLocation(loc);
    _centerMap(loc.latLng, 14.5);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Located GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (${loc.label})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleScanOsmViewport() async {
    final bounds = _mapController.camera.visibleBounds;
    final count = await ref.read(stationControllerProvider.notifier).scanOsmViewport(
          minLat: bounds.southWest.latitude,
          minLng: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLng: bounds.northEast.longitude,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? 'Discovered $count live OSM chargers' : 'Viewport already up to date with OSM network'),
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

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(initialCenter: _kDefaultCenter, initialZoom: 12.0, minZoom: 5.0, maxZoom: 18.0),
            children: [
              TileLayer(urlTemplate: mapStyle.urlTemplate, userAgentPackageName: 'my.ukm.chargetrail.v2'),
              MarkerLayer(
                markers: [
                  if (userLoc != null)
                    Marker(point: userLoc.latLng, width: 34, height: 34, child: const UserLocationMarkerWidget()),
                  ...state.filteredStations.map((station) {
                    final isSelected = state.selectedStation?.id == station.id;
                    return Marker(
                      point: LatLng(station.latitude, station.longitude),
                      width: isSelected ? 48 : 40,
                      height: isSelected ? 48 : 40,
                      child: GestureDetector(
                        onTap: () {
                          notifier.selectStation(station);
                          StationDetailSheet.show(context, station);
                        },
                        child: _markerIcon(station.maxPowerKw >= 120.0, isSelected, station.source == 'osm_live'),
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
                        onTap: () {
                          notifier.loadStations();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconnecting...'), duration: Duration(seconds: 1)));
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

          // Floating Bottom Controls: Counter, Add Charger & GPS
          Positioned(
            bottom: 20,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                        Text('${state.filteredStations.length} stations', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                if (state.selectedStation != null) ...[
                  const SizedBox(height: 8),
                  _buildPreviewCard(context, state.selectedStation!, isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _markerIcon(bool isUltraFast, bool isSelected, bool isOsmLive) {
    final color = isOsmLive ? const Color(0xFF0284C7) : (isUltraFast ? AppTheme.ultraFastColor : AppTheme.primaryTeal);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? Colors.amber : Colors.white, width: isSelected ? 3.0 : 1.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)],
      ),
      child: Center(
        child: Icon(isUltraFast ? Icons.bolt : (isOsmLive ? Icons.public : Icons.ev_station), color: Colors.white, size: isSelected ? 24 : 20),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, ChargingStation station, bool isDark) {
    return GestureDetector(
      onTap: () => StationDetailSheet.show(context, station),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.ev_station, color: AppTheme.primaryTeal, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${station.operatorName ?? "Community"} • ${station.maxPowerKw.toInt()} kW', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
