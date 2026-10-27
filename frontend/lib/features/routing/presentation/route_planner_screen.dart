import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/map_tile_config.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/stations/presentation/widgets/station_detail_sheet.dart';
import 'package:latlong2/latlong.dart';
import '../domain/route_models.dart';
import 'route_controller.dart';
import 'widgets/route_search_card.dart';
import 'widgets/route_telemetry_card.dart';

/// Which floating panel is actively expanded on the route planner screen.
enum ActiveRoutePanel { none, search, telemetry }

/// Main interactive EV Route Planner screen with OSRM polylines, map styles, and charging stops.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final MapController _mapController = MapController();
  RoutePlanResult? _lastFittedPlan;
  ActiveRoutePanel _activePanel = ActiveRoutePanel.none;

  static const LatLng _kMalaysianCenter = LatLng(3.8, 101.4);

  void _fitRouteBounds(RoutePlanResult plan) {
    if (plan.polylinePoints.length < 2 || _lastFittedPlan == plan) return;
    _lastFittedPlan = plan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(plan.polylinePoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(left: 36, right: 36, top: 120, bottom: 100),
          ),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeControllerProvider);
    final mapStyle = ref.watch(mapTileStyleProvider);
    final plan = state.currentPlan;

    if (plan != null) {
      _fitRouteBounds(plan);
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Polyline & Waypoint Markers Layer (KF13)
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (_activePanel != ActiveRoutePanel.none) {
                setState(() => _activePanel = ActiveRoutePanel.none);
              }
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _kMalaysianCenter,
                initialZoom: 7.5,
                minZoom: 5.0,
                maxZoom: 18.0,
                onTap: (_, point) {
                  if (_activePanel != ActiveRoutePanel.none) {
                    setState(() => _activePanel = ActiveRoutePanel.none);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: mapStyle.urlTemplate,
                  userAgentPackageName: 'com.chargetrail.v2',
                ),
                if (plan != null && plan.polylinePoints.isNotEmpty) ...[
                  // Two-Tone Road Polyline (Dark Teal Border + Bright Cyan Core)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: plan.polylinePoints,
                        color: const Color(0xFF0F3E3B), // Dark Teal Outer Border
                        strokeWidth: 7.0,
                      ),
                      Polyline(
                        points: plan.polylinePoints,
                        color: const Color(0xFF00E5FF), // Bright Cyan Inner Road Core
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
                      // Corridor Vicinity Chargers (Compact Teal EV Pins)
                      ...plan.corridorStations
                          .where((cs) => !plan.recommendedStops.any((rs) => rs.station.id == cs.id))
                          .map((station) {
                        return Marker(
                          point: LatLng(station.latitude, station.longitude),
                          width: 26,
                          height: 26,
                          child: GestureDetector(
                            onTap: () => StationDetailSheet.show(context, station),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.ev_station, color: Colors.white, size: 14),
                            ),
                          ),
                        );
                      }),
                      // Recommended Charging Stop Markers (Orange Lightning Bolt)
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
          ),

          // 2. Top Interactive Route Control Panel (Free-Text Search & SoC)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: RouteSearchCard(
                  isExpanded: _activePanel == ActiveRoutePanel.search,
                  onToggleExpand: () {
                    setState(() {
                      _activePanel = _activePanel == ActiveRoutePanel.search
                          ? ActiveRoutePanel.none
                          : ActiveRoutePanel.search;
                    });
                  },
                  onPlanRouteCompleted: () {
                    setState(() {
                      _activePanel = ActiveRoutePanel.none;
                    });
                  },
                ),
              ),
            ),
          ),

          // 3. Bottom Expandable Battery Telemetry & Stop Timeline Sheet (KF14, KF15)
          if (plan != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: RouteTelemetryCard(
                    plan: plan,
                    origin: state.origin,
                    destination: state.destination,
                    isExpanded: _activePanel == ActiveRoutePanel.telemetry,
                    onToggleExpand: () {
                      setState(() {
                        _activePanel = _activePanel == ActiveRoutePanel.telemetry
                            ? ActiveRoutePanel.none
                            : ActiveRoutePanel.telemetry;
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
