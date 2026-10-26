import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stations/presentation/widgets/station_detail_sheet.dart';
import '../../domain/route_models.dart';

/// Card presenting trip battery telemetry, range anxiety classification, and charging itinerary.
class RouteTelemetryCard extends StatelessWidget {
  final RoutePlanResult plan;

  const RouteTelemetryCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Range Anxiety Risk Banner (KF14)
        _buildRangeAnxietyBanner(isDark),
        const SizedBox(height: 14),

        // 2. Journey Telemetry Overview Grid
        _buildTelemetryGrid(isDark),
        const SizedBox(height: 16),

        // 3. Recommended Charging Stops Timeline (KF15)
        _buildChargingStopsTimeline(context, isDark),
      ],
    );
  }

  Widget _buildRangeAnxietyBanner(bool isDark) {
    Color bannerColor;
    IconData icon;
    String title;

    if (plan.isSafe) {
      bannerColor = AppTheme.successGreen;
      icon = Icons.shield;
      title = 'Safe Range • No Charging Stops Required';
    } else if (plan.isWarning) {
      bannerColor = Colors.orange[800]!;
      icon = Icons.warning_amber_rounded;
      title = 'Warning • Approaching Safety Reserve Buffer';
    } else {
      bannerColor = const Color(0xFFDC2626); // Crimson red
      icon = Icons.battery_alert;
      title = 'Critical • Highway Charging Stop Mandatory';
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, color: bannerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: bannerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.statusSummary,
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Vehicle: ${plan.vehicleSummary}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _metricCol('Total Distance', '${plan.totalDistanceKm} km', Icons.route),
              _metricCol('Drive Time', '${plan.estimatedDriveMinutes} mins', Icons.timer_outlined),
              _metricCol('Charge Time', '${plan.totalChargingMinutes} mins', Icons.electric_bolt),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              _metricCol(
                'Starting SoC',
                '${plan.startingSocPercent}%',
                Icons.battery_full,
              ),
              _metricCol(
                'Direct Arrival SoC',
                '${plan.projectedDestinationSocWithoutCharging}%',
                Icons.battery_unknown,
              ),
              _metricCol(
                'Final Arrival SoC',
                '${plan.finalArrivalSocPercent}%',
                Icons.battery_charging_full,
                color: AppTheme.primaryTeal,
              ),
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
              Icon(icon, size: 13, color: color ?? Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargingStopsTimeline(BuildContext context, bool isDark) {
    if (plan.recommendedStops.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Direct Route • No charging stops required',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
                'Recommended Charging Stops (${plan.recommendedStops.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Tap for access guide',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...plan.recommendedStops.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final stop = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.ultraFastColor,
                child: Text(
                  '$idx',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                stop.station.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Arrive ${stop.arrivalSocPercent}% -> Charge to ${stop.departureSocPercent}% • '
                '~${stop.estimatedChargeMinutes} mins (RM ${stop.estimatedCostMyr.toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => StationDetailSheet.show(context, stop.station),
            ),
          );
        }),
      ],
    );
  }
}
