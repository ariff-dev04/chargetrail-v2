import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/stations/presentation/widgets/station_detail_sheet.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_repository.dart';
import '../domain/route_models.dart';
import 'route_controller.dart';
import 'widgets/route_telemetry_card.dart';

/// Main interactive EV Route Planner screen with OSRM polylines and charging stops.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final MapController _mapController = MapController();

  static const LatLng _kMalaysianCenter = LatLng(3.8, 101.4);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeControllerProvider);
    final notifier = ref.read(routeControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = state.currentPlan;

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Polyline & Waypoint Markers Layer (KF13)
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _kMalaysianCenter,
              initialZoom: 7.5,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.chargetrail.v2',
              ),
              if (plan != null && plan.polylinePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: plan.polylinePoints,
                      color: AppTheme.primaryTeal,
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Origin Pin (Green)
                    Marker(
                      point: state.origin.latLng,
                      width: 32,
                      height: 32,
                      child: const Icon(Icons.trip_origin, color: AppTheme.successGreen, size: 24),
                    ),
                    // Destination Pin (Red)
                    Marker(
                      point: state.destination.latLng,
                      width: 32,
                      height: 32,
                      child: const Icon(Icons.flag, color: Colors.red, size: 28),
                    ),
                    // Recommended Charging Stop Markers (Orange Lightning)
                    ...plan.recommendedStops.map((stop) {
                      return Marker(
                        point: LatLng(stop.station.latitude, stop.station.longitude),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => StationDetailSheet.show(context, stop.station),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.ultraFastColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 22),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),

          // 2. Top Interactive Route Control Panel (KF10)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEndpointSelector(context, state, notifier),
                      const SizedBox(height: 8),

                      // Starting Battery SoC Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Starting Battery SoC:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(
                            '${state.startingSocPercent}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                          ),
                        ],
                      ),
                      Slider(
                        value: state.startingSocPercent.toDouble(),
                        min: 15,
                        max: 100,
                        divisions: 17,
                        activeColor: AppTheme.primaryTeal,
                        onChanged: (v) => notifier.setStartingSoc(v.round()),
                      ),

                      // Rapid Testing Route Presets
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            label: const Text('KL -> Putrajaya (Safe)', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.verified, size: 14, color: AppTheme.successGreen),
                            onPressed: () {
                              notifier.applyPreset(
                                origin: RouteRepository.defaultHubs[0], // KLCC
                                destination: RouteRepository.defaultHubs[2], // Putrajaya
                                startingSoc: 80,
                              );
                            },
                          ),
                          ActionChip(
                            label: const Text('KL -> Penang (Needs Stop)', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.bolt, size: 14, color: AppTheme.ultraFastColor),
                            onPressed: () {
                              notifier.applyPreset(
                                origin: RouteRepository.defaultHubs[0], // KLCC
                                destination: RouteRepository.defaultHubs[1], // Penang
                                startingSoc: 55,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Expandable Battery Telemetry & Stop Timeline Sheet (KF14, KF15)
          if (plan != null)
            DraggableScrollableSheet(
              initialChildSize: 0.32,
              minChildSize: 0.18,
              maxChildSize: 0.75,
              snap: true,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RouteTelemetryCard(plan: plan),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEndpointSelector(
    BuildContext context,
    RouteState state,
    RouteNotifier notifier,
  ) {
    final hubs = RouteRepository.defaultHubs;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              DropdownButtonFormField<PlaceSuggestion>(
                initialValue: state.origin,
                decoration: const InputDecoration(
                  labelText: 'Origin',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: hubs.map((h) => DropdownMenuItem(value: h, child: Text(h.name, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => val != null ? notifier.setOrigin(val) : null,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<PlaceSuggestion>(
                initialValue: state.destination,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: hubs.map((h) => DropdownMenuItem(value: h, child: Text(h.name, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => val != null ? notifier.setDestination(val) : null,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.swap_vert, color: AppTheme.primaryTeal),
          tooltip: 'Swap Endpoints',
          onPressed: () => notifier.swapOriginDestination(),
        ),
      ],
    );
  }
}
