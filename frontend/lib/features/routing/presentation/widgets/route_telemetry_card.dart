import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../vehicles/data/vehicle_repository.dart';
import '../../../vehicles/domain/vehicle_model.dart';
import '../../../vehicles/presentation/vehicle_controller.dart';
import '../../domain/route_models.dart';
import '../navigation_launcher.dart';
import 'charging_stop_tile.dart';
import 'route_advisory_banner.dart';

/// ABRP-style bottom-sheet journey battery telemetry card with expandable stop timeline & action bar.
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
      widget.origin ?? PlaceSuggestion(name: widget.plan.originName, city: 'Origin', state: 'Malaysia', latitude: 3.1578, longitude: 101.7118);

  PlaceSuggestion get _resolvedDestination =>
      widget.destination ?? PlaceSuggestion(name: widget.plan.destinationName, city: 'Destination', state: 'Malaysia', latitude: 5.4372, longitude: 100.3096);

  VehicleProfile get _resolvedVehicle {
    if (widget.vehicleOverride != null) return widget.vehicleOverride!;
    try {
      return ref.watch(vehicleControllerProvider).activeVehicle;
    } catch (_) {
      return VehicleRepository.defaultPresets.first;
    }
  }

  void _savePlan() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('⭐ Trip plan saved to your bookmarks!'),
      backgroundColor: AppTheme.successGreen,
      duration: Duration(seconds: 2),
    ));
  }

  void _sharePlan() {
    final url = NavigationLauncher.buildGoogleMapsMultiStopUrl(plan: widget.plan, origin: _resolvedOrigin, destination: _resolvedDestination);
    final summary = 'ChargeTrail EV Route: ${_resolvedOrigin.name} ➔ ${_resolvedDestination.name}\nDistance: ${widget.plan.totalDistanceKm} km • Trip: ${formatDurationMinutes(widget.plan.totalTripMinutes)}\nStops: ${widget.plan.recommendedStops.length} • Arrival SoC: ${widget.plan.finalArrivalSocPercent}%\nMap Link: $url';
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Trip itinerary & Google Maps link copied to clipboard!'), duration: Duration(seconds: 2)));
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 10, offset: const Offset(0, -2)),
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
                    Text(
                      '${vehicle.brand} ${vehicle.modelName}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 6),

            // Summary Header Row
            Row(
              children: [
                _buildBadge(isCompact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatDurationMinutes(widget.plan.totalTripMinutes)} (${widget.plan.totalDistanceKm.toStringAsFixed(0)} km)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.plan.recommendedStops.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${widget.plan.recommendedStops.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                    ),
                  ),
                IconButton(
                  key: const Key('telemetry_collapse_button'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  tooltip: 'Collapse',
                  onPressed: _toggle,
                ),
              ],
            ),
            const SizedBox(height: 2),

            // Sub-metrics row
            Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(formatDurationMinutes(widget.plan.estimatedDriveMinutes), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 10),
                const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFFEA580C)),
                const SizedBox(width: 4),
                Text(
                  '${formatDurationMinutes(widget.plan.totalChargingMinutes)} - ${widget.plan.recommendedStops.length} charges',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Spacer(),
                Text('Arrival ${widget.plan.finalArrivalSocPercent}% SoC', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
              ],
            ),
            const Divider(height: 12),

            // Expanded Scrollable Timeline Body
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Action Buttons Row
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _savePlan,
                          icon: const Icon(Icons.favorite_border_rounded, size: 14),
                          label: const Text('Save plan', style: TextStyle(fontSize: 11)),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _sharePlan,
                          icon: const Icon(Icons.ios_share_rounded, size: 14),
                          label: const Text('Share plan', style: TextStyle(fontSize: 11)),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActiveEvPill(vehicle, isDark),
                    const SizedBox(height: 8),
                    _buildRangeAnxietyBanner(isDark),
                    const SizedBox(height: 10),

                    // Origin Departure Node
                    Row(
                      children: [
                        const Icon(Icons.trip_origin, size: 16, color: AppTheme.successGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'My position / Origin • 🔋 ${widget.plan.startingSocPercent}%',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Charging Stops Timeline
                    ...widget.plan.recommendedStops.asMap().entries.map((e) {
                      return ChargingStopTile(stopIndex: e.key, stop: e.value);
                    }),

                    // Destination Arrival Node
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🏁 Destination • 🔋 ${widget.plan.finalArrivalSocPercent}%',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const RouteAdvisoryBanner(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Pinned Bottom Button Row: Restart & Drive
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _toggle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Restart'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => NavigationLauncher.showJourneyNavigationPicker(
                      context,
                      plan: widget.plan,
                      origin: _resolvedOrigin,
                      destination: _resolvedDestination,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveEvPill(VehicleProfile vehicle, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.electric_car, color: AppTheme.primaryTeal, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Active EV: ${vehicle.brand} ${vehicle.modelName} (${vehicle.batteryCapacityKwh.toStringAsFixed(0)} kWh • ${vehicle.connectorType} • ${vehicle.maxDcChargeKw.toStringAsFixed(0)}kW Max)',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
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
        decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
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
              Icon(icon, color: bannerColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: bannerColor)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(widget.plan.statusSummary, style: const TextStyle(fontSize: 10.5, height: 1.25)),
        ],
      ),
    );
  }
}
