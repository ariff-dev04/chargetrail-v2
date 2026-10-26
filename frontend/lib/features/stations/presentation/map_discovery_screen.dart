import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';
import '../domain/station_model.dart';
import 'station_controller.dart';
import 'widgets/station_detail_sheet.dart';
import 'widgets/station_filter_bar.dart';

/// Main EV Charging Station map discovery view powered by OpenStreetMap tiles.
class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen> {
  final MapController _mapController = MapController();

  // Default coordinate center: Kuala Lumpur City Centre
  static const LatLng _kDefaultCenter = LatLng(3.1578, 101.7118);

  void _centerMap(LatLng target) {
    _mapController.move(target, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationControllerProvider);
    final notifier = ref.read(stationControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Pure Dart Map Layer
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _kDefaultCenter,
              initialZoom: 12.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.chargetrail.v2',
              ),
              MarkerLayer(
                markers: state.filteredStations.map((station) {
                  final isSelected = state.selectedStation?.id == station.id;
                  final isUltraFast = station.maxPowerKw >= 120.0;

                  return Marker(
                    point: LatLng(station.latitude, station.longitude),
                    width: isSelected ? 52 : 44,
                    height: isSelected ? 52 : 44,
                    child: GestureDetector(
                      onTap: () {
                        notifier.selectStation(station);
                        StationDetailSheet.show(context, station);
                      },
                      child: _buildMarkerIcon(isUltraFast, isSelected),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Top Floating Filter Bar Overlay & Offline Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Offline Failover Mode Banner
                    if (state.isOfflineMode) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Offline Mode • Serving Cached Stations',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Horizontal Filter Bar
                    StationFilterBar(
                      activeFilter: state.activeFilter,
                      onSearchChanged: notifier.setSearchQuery,
                      onToggleConnector: notifier.toggleConnector,
                      onToggleMinKw: notifier.toggleMinKw,
                      onToggle24Hours: notifier.toggle24Hours,
                      onToggleAmenity: notifier.toggleAmenity,
                      onReset: notifier.resetFilters,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Bottom Controls & Station Counter Badge
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Station Count Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.ev_station,
                            size: 16,
                            color: AppTheme.primaryTeal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${state.filteredStations.length} stations found',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Recenter Action Floating Button
                    FloatingActionButton.small(
                      heroTag: 'recenter_map_fab',
                      onPressed: () => _centerMap(_kDefaultCenter),
                      backgroundColor:
                          isDark ? AppTheme.cardDark : Colors.white,
                      foregroundColor: AppTheme.primaryTeal,
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),

                // Selected Station Quick Preview Card
                if (state.selectedStation != null) ...[
                  const SizedBox(height: 10),
                  _buildQuickPreviewCard(
                    context,
                    state.selectedStation!,
                    isDark,
                    () => StationDetailSheet.show(
                      context,
                      state.selectedStation!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerIcon(bool isUltraFast, bool isSelected) {
    final baseColor =
        isUltraFast ? AppTheme.ultraFastColor : AppTheme.primaryTeal;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.amber : Colors.white,
          width: isSelected ? 3.5 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isUltraFast ? Icons.bolt : Icons.ev_station,
          color: Colors.white,
          size: isSelected ? 26 : 22,
        ),
      ),
    );
  }

  Widget _buildQuickPreviewCard(
    BuildContext context,
    ChargingStation station,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.ev_station,
                color: AppTheme.primaryTeal,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${station.operatorName ?? "Community"} • ${station.maxPowerKw.toInt()} kW',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
