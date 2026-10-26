import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/station_model.dart';
import 'station_detail_sheet.dart';

/// Horizontal carousel displaying nearby EV chargers sorted by ascending distance.
class NearbyStationsCarousel extends StatelessWidget {
  final List<ChargingStation> stations;
  final double Function(double lat, double lng) distanceCalculator;
  final void Function(ChargingStation station) onStationTap;

  const NearbyStationsCarousel({
    super.key,
    required this.stations,
    required this.distanceCalculator,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '📍 Nearby Chargers (${stations.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openFullNearbySheet(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View List',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: AppTheme.primaryTeal),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: stations.length > 15 ? 15 : stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              final dist = distanceCalculator(station.latitude, station.longitude);
              return _buildCarouselCard(context, station, dist, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(
    BuildContext context,
    ChargingStation station,
    double distKm,
    bool isDark,
  ) {
    final isOpenData = station.source == 'osm_live' || station.source == 'open_data_my';

    return GestureDetector(
      onTap: () => onStationTap(station),
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${distKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isOpenData ? 'Open Data' : 'Verified DB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isOpenData ? const Color(0xFF0284C7) : AppTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              station.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              '${station.maxPowerKw.toInt()} kW • ${station.city}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullNearbySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.90,
          expand: false,
          builder: (ctx, scroll) {
            return ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: stations.length,
              itemBuilder: (ctx, index) {
                final s = stations[index];
                final dist = distanceCalculator(s.latitude, s.longitude);
                final isOpen = s.source == 'osm_live' || s.source == 'open_data_my';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      child: Text(
                        '${dist.toStringAsFixed(1)}km',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                      ),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${s.maxPowerKw.toInt()} kW • ${s.city} • ${isOpen ? "Open Data" : "Verified"}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      onStationTap(s);
                      StationDetailSheet.show(context, s);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
