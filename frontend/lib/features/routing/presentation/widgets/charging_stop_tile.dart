import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stations/presentation/widgets/station_detail_sheet.dart';
import '../../domain/route_models.dart';
import '../navigation_launcher.dart';
import '../route_controller.dart';

/// Single charging stop card with ABRP-style vicinity alternative stop switcher.
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
    final idx = stopIndex + 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.ultraFastColor,
                  child: Text(
                    '$idx',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => StationDetailSheet.show(context, stop.station),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.station.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stop.distanceFromOriginKm} km from start • ${stop.station.operatorName} • ${stop.station.maxPowerKw.toInt()} kW',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.directions, color: AppTheme.primaryTeal, size: 20),
                  tooltip: 'Navigate',
                  onPressed: () => NavigationLauncher.showStopNavigationPicker(
                    context,
                    stationName: stop.station.name,
                    lat: stop.station.latitude,
                    lng: stop.station.longitude,
                    city: stop.station.city,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.info_outline, size: 18),
                  tooltip: 'Access Guide',
                  onPressed: () => StationDetailSheet.show(context, stop.station),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Arrive ${stop.arrivalSocPercent}% ➔ ${stop.departureSocPercent}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${formatDurationMinutes(stop.estimatedChargeMinutes)} (RM ${stop.estimatedCostMyr.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (stop.nearbyAlternatives.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  key: Key('swap_stop_button_$stopIndex'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.4)),
                  avatar: const Icon(Icons.swap_horiz, size: 14, color: AppTheme.primaryTeal),
                  label: Text(
                    'Swap Stop (${stop.nearbyAlternatives.length} in vicinity)',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                  ),
                  onPressed: () => _showVicinitySwapSheet(context, ref),
                ),
              ),
            ],
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
