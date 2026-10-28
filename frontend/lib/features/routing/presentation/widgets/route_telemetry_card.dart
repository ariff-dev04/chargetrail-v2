import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../vehicles/data/vehicle_repository.dart';
import '../../../vehicles/domain/vehicle_model.dart';
import '../../../vehicles/presentation/vehicle_controller.dart';
import '../../domain/route_models.dart';
import '../navigation_launcher.dart';
import 'charging_stop_tile.dart';
class RouteTelemetryCard extends ConsumerStatefulWidget {
  final RoutePlanResult plan;
  final PlaceSuggestion? origin;
  final PlaceSuggestion? destination;
  final bool? isExpanded;
  final VoidCallback? onToggleExpand;
  final VehicleProfile? vehicleOverride;
  const RouteTelemetryCard({
    super.key,
    required this.plan,
    this.origin,
    this.destination,
    this.isExpanded,
    this.onToggleExpand,
    this.vehicleOverride,
  });
  @override
  ConsumerState<RouteTelemetryCard> createState() => _RouteTelemetryCardState();
}
class _RouteTelemetryCardState extends ConsumerState<RouteTelemetryCard> {
  late bool _localExpanded = widget.isExpanded ?? false;
  bool get _isExpanded =>
      widget.onToggleExpand != null ? (widget.isExpanded ?? false) : _localExpanded;
  void _toggle() {
    if (widget.onToggleExpand != null) {
      widget.onToggleExpand!();
    } else {
      setState(() => _localExpanded = !_localExpanded);
    }
  }
  PlaceSuggestion get _resolvedOrigin =>
      widget.origin ??
      PlaceSuggestion(
        name: widget.plan.originName,
        city: 'Origin',
        state: 'Malaysia',
        latitude: 3.1578,
        longitude: 101.7118,
      );
  PlaceSuggestion get _resolvedDestination =>
      widget.destination ??
      PlaceSuggestion(
        name: widget.plan.destinationName,
        city: 'Destination',
        state: 'Malaysia',
        latitude: 5.4372,
        longitude: 100.3096,
      );
  VehicleProfile get _resolvedVehicle {
    if (widget.vehicleOverride != null) {
      return widget.vehicleOverride!;
    }
    try {
      return ref.watch(vehicleControllerProvider).activeVehicle;
    } catch (_) {
      return VehicleRepository.defaultPresets.first;
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = _resolvedVehicle;
    if (!_isExpanded) {
      return GestureDetector(
        key: const Key('collapsed_telemetry_bar'),
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildBadge(isCompact: true),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.plan.totalDistanceKm} km • ${formatDurationMinutes(widget.plan.totalTripMinutes)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${vehicle.brand} ${vehicle.modelName}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: () => NavigationLauncher.showJourneyNavigationPicker(
                  context,
                  plan: widget.plan,
                  origin: _resolvedOrigin,
                  destination: _resolvedDestination,
                ),
                icon: const Icon(Icons.navigation, size: 12),
                label: const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
                tooltip: 'Expand',
                onPressed: _toggle,
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      key: const Key('expanded_telemetry_sheet'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Journey Battery Telemetry',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('telemetry_collapse_button'),
                    onPressed: _toggle,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                    label: const Text('Collapse', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildActiveEvPill(vehicle, isDark),
              const SizedBox(height: 8),
              _buildRangeAnxietyBanner(isDark),
              const SizedBox(height: 10),
              _buildTelemetryGrid(isDark),
              const SizedBox(height: 12),
              _buildChargingStopsTimeline(context, isDark),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => NavigationLauncher.showJourneyNavigationPicker(
                    context,
                    plan: widget.plan,
                    origin: _resolvedOrigin,
                    destination: _resolvedDestination,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Start Journey in Navigation App',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildActiveEvPill(VehicleProfile vehicle, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.electric_car, color: AppTheme.primaryTeal, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Active EV: ${vehicle.brand} ${vehicle.modelName} (${vehicle.batteryCapacityKwh.toStringAsFixed(0)} kWh • ${vehicle.connectorType} • ${vehicle.maxDcChargeKw.toStringAsFixed(0)}kW Max)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildBadge({required bool isCompact}) {
    Color col;
    String label;
    IconData icon;
    if (widget.plan.isSafe) {
      col = AppTheme.successGreen;
      label = 'Safe';
      icon = Icons.shield;
    } else if (widget.plan.isWarning) {
      col = Colors.orange[800]!;
      label = 'Tight Buffer';
      icon = Icons.warning_amber_rounded;
    } else {
      col = const Color(0xFFDC2626);
      label = 'Stop Required';
      icon = Icons.battery_alert;
    }
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: col, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      );
    }
    return Icon(icon, color: col, size: 20);
  }
  Widget _buildRangeAnxietyBanner(bool isDark) {
    Color bannerColor;
    IconData icon;
    String title;
    if (widget.plan.isSafe) {
      bannerColor = AppTheme.successGreen;
      icon = Icons.shield;
      title = 'Safe Range • No Charging Stops Required';
    } else if (widget.plan.isWarning) {
      bannerColor = Colors.orange[800]!;
      icon = Icons.warning_amber_rounded;
      title = 'Warning • Approaching Safety Reserve Buffer';
    } else {
      bannerColor = const Color(0xFFDC2626);
      icon = Icons.battery_alert;
      title = 'Critical • Highway Charging Stop Mandatory';
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: bannerColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: bannerColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.plan.statusSummary, style: const TextStyle(fontSize: 11, height: 1.25)),
        ],
      ),
    );
  }
  Widget _buildTelemetryGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _metricCol('Distance', '${widget.plan.totalDistanceKm} km', Icons.route),
              _metricCol('Drive Time', formatDurationMinutes(widget.plan.estimatedDriveMinutes), Icons.timer_outlined),
              _metricCol('Charge Time', formatDurationMinutes(widget.plan.totalChargingMinutes), Icons.electric_bolt),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: [
              _metricCol('Start SoC', '${widget.plan.startingSocPercent}%', Icons.battery_full),
              _metricCol('Direct SoC', '${widget.plan.projectedDestinationSocWithoutCharging}%', Icons.battery_unknown),
              _metricCol('Final SoC', '${widget.plan.finalArrivalSocPercent}%', Icons.battery_charging_full, color: AppTheme.primaryTeal),
            ],
          ),
        ],
      ),
    );
  }
  Widget _metricCol(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color ?? Colors.grey),
              const SizedBox(width: 3),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
  Widget _buildChargingStopsTimeline(BuildContext context, bool isDark) {
    if (widget.plan.recommendedStops.isEmpty) {
      final isDeficit = widget.plan.rangeAnxietyStatus == 'critical_charging_required' ||
          widget.plan.finalArrivalSocPercent <= 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDeficit
                  ? const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.1)
                  : (isDark ? AppTheme.cardDark : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
              border: isDeficit ? Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  isDeficit ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: isDeficit ? const Color(0xFFDC2626) : AppTheme.successGreen,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDeficit
                        ? 'No compatible highway charger found on corridor — tap Edit or scan area'
                        : 'Direct Route • No charging stops required',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDeficit ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDriverDisclaimer(isDark),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recommended Charging Stops (${widget.plan.recommendedStops.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Text('Tap for access guide', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 6),
        ...widget.plan.recommendedStops.asMap().entries.map((entry) {
          return ChargingStopTile(
            stopIndex: entry.key,
            stop: entry.value,
          );
        }),
        _buildDriverDisclaimer(isDark),
      ],
    );
  }

  Widget _buildDriverDisclaimer(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primaryTeal),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Disclaimer: Route & charger locations are sourced from open community data (OpenStreetMap). Always verify highway direction (Northbound/Southbound R&R), charger availability, and parking access rules before navigating.',
              style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
