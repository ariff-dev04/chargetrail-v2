import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stations/presentation/widgets/operator_marker_badge.dart';
import '../../../stations/presentation/widgets/station_detail_sheet.dart';
import '../../domain/route_models.dart';
import '../navigation_launcher.dart';
import '../route_controller.dart';

/// Single charging stop card with ABRP-style vertical timeline node and vicinity alternative stop switcher.
class ChargingStopTile extends ConsumerWidget {
  final int stopIndex;
  final ChargingStopRecommendation stop;

  const ChargingStopTile({
    super.key,
    required this.stopIndex,
    required this.stop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final operatorTheme = OperatorBrandTheme.fromStation(stop.station);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left vertical timeline node
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${stop.estimatedChargeMinutes} min',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: isDark ? 0.3 : 0.25),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Right stop card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => StationDetailSheet.show(context, stop.station),
                            child: Text(
                              '[${operatorTheme.label}] ${stop.station.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        InkWell(
                          key: Key('swap_stop_button_$stopIndex'),
                          onTap: () => _showVicinitySwapSheet(context, ref),
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryTeal),
                          ),
                        ),
                        InkWell(
                          onTap: () => NavigationLauncher.showStopNavigationPicker(
                            context,
                            stationName: stop.station.name,
                            lat: stop.station.latitude,
                            lng: stop.station.longitude,
                            city: stop.station.city,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.directions_rounded, size: 20, color: AppTheme.primaryTeal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Subtitle row: SoC progress, kW badge, access badge
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.battery_4_bar_rounded, size: 14, color: AppTheme.primaryTeal),
                            const SizedBox(width: 3),
                            Text(
                              '${stop.arrivalSocPercent}% → ${stop.departureSocPercent}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${stop.station.maxPowerKw.toInt()} kW',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                          ),
                        ),
                        if (stop.station.parkingLevel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stop.station.parkingLevel!,
                              style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${stop.distanceFromOriginKm} km • RM ${stop.estimatedCostMyr.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                        if (stop.nearbyAlternatives.isNotEmpty)
                          InkWell(
                            onTap: () => _showVicinitySwapSheet(context, ref),
                            child: Text(
                              'Swap Stop (${stop.nearbyAlternatives.length} in vicinity)',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVicinitySwapSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route, color: AppTheme.primaryTeal, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vicinity Chargers Along Corridor',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Current stop #${stopIndex + 1}: ${stop.station.name}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Divider(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: stop.nearbyAlternatives.length,
                    separatorBuilder: (_, _) => const Divider(height: 8),
                    itemBuilder: (ctx, i) {
                      final alt = stop.nearbyAlternatives[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                          child: const Icon(Icons.ev_station, color: AppTheme.primaryTeal, size: 18),
                        ),
                        title: Text(
                          alt.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${alt.operatorName} • ${alt.maxPowerKw.toInt()} kW • ${alt.city}\n${alt.parkingLevel}',
                          style: const TextStyle(fontSize: 10),
                          maxLines: 2,
                        ),
                        trailing: ElevatedButton(
                          key: Key('prioritize_stop_${alt.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(80, 30),
                          ),
                          onPressed: () {
                            ref
                                .read(routeControllerProvider.notifier)
                                .swapStopStation(stopIndex, alt);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Prioritize Stop', style: TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
