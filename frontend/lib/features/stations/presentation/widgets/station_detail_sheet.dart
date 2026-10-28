import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../community/presentation/widgets/micro_survey_card.dart';
import '../../../routing/presentation/navigation_launcher.dart';
import '../../../vehicles/presentation/vehicle_controller.dart';
import '../../domain/station_model.dart';

/// Modal detail sheet showing tariffs, parking level, plugs, active EV charge time, and access steps.
class StationDetailSheet extends StatelessWidget {
  final ChargingStation station;
  final VoidCallback? onNavigatePressed;

  const StationDetailSheet({
    super.key,
    required this.station,
    this.onNavigatePressed,
  });

  static void show(BuildContext context, ChargingStation station) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationDetailSheet(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Operator, Verified & Bookmark
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(station.operatorName ?? 'Community Station', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                  ),
                  if (station.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 15, color: Colors.blue),
                    const SizedBox(width: 2),
                    const Text('Verified', style: TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(authControllerProvider).currentUser;
                      final isSaved = user?.isBookmarked(station.id) ?? false;
                      return IconButton(
                        icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? AppTheme.primaryTeal : Colors.grey, size: 20),
                        onPressed: () => ref.read(authControllerProvider.notifier).toggleBookmark(station.id),
                      );
                    },
                  ),
                  const Icon(Icons.star, size: 15, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text('${station.rating.toStringAsFixed(1)} (${station.reviewCount})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),

              // Name & Availability
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(station.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: station.isAvailable ? AppTheme.successGreen.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(station.isAvailable ? 'Available' : 'Unavailable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: station.isAvailable ? AppTheme.successGreen : Colors.grey)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(station.address, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 12),

              _buildPricingCard(isDark),
              const SizedBox(height: 12),

              Text('Available Connectors', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildPlugs(isDark),
              const SizedBox(height: 12),

              if (station.howToAccess.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.navigation, size: 16, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Text('How to Access Charger', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                _buildSteps(),
                const SizedBox(height: 12),
              ],

              if (station.amenities.isNotEmpty) ...[
                Text('Nearby Amenities', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: station.amenities.map((a) => Chip(avatar: Icon(_amenityIcon(a), size: 13), label: Text(a, style: const TextStyle(fontSize: 11)), padding: const EdgeInsets.symmetric(horizontal: 2))).toList(),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 16),
              MicroSurveyCard(stationId: station.id),
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: onNavigatePressed ??
                    () {
                      Navigator.of(context).pop();
                      NavigationLauncher.showStationNavigationSheet(context, station);
                    },
                icon: const Icon(Icons.directions),
                label: const Text('Navigate to Station'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D28) : const Color(0xFFF1F8F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2C3E36) : const Color(0xFFD4ECE1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _infoCol('Charging Tariff', station.chargingCostMyr > 0 ? 'RM ${station.chargingCostMyr.toStringAsFixed(2)} / kWh' : 'Free Charging', Icons.electric_bolt, AppTheme.primaryTeal),
              const SizedBox(width: 12),
              _infoCol('Parking Fee', station.parkingFeeMyr > 0 ? 'RM ${station.parkingFeeMyr.toStringAsFixed(2)}' : 'Free Entry', Icons.local_parking, Colors.orange[700]!),
            ],
          ),
          if (station.parkingLevel != null && station.parkingLevel!.isNotEmpty) ...[
            const Divider(height: 14),
            Row(
              children: [
                const Icon(Icons.layers, size: 15, color: AppTheme.primaryTeal),
                const SizedBox(width: 6),
                const Text('Parking Level: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Expanded(child: Text(station.parkingLevel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal))),
              ],
            ),
          ],
          Consumer(
            builder: (context, ref, _) {
              final activeEv = ref.watch(vehicleControllerProvider).activeVehicle;
              final mins = activeEv.estimateChargeMinutes20To80(station.maxPowerKw);
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 15, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Est. 20%->80% for ${activeEv.displayName}: ~$mins mins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlugs(bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: station.plugTypes.map((plug) {
        final isFast = plug.powerKw >= 120.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23322D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isFast ? AppTheme.ultraFastColor : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ev_station, size: 15, color: isFast ? AppTheme.ultraFastColor : AppTheme.primaryTeal),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plug.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('${plug.powerKw.toInt()} kW • ${plug.count} bays', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSteps() {
    return Column(
      children: station.howToAccess.map((step) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 9, backgroundColor: AppTheme.primaryTeal, child: Text('${step.stepNumber}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(width: 6),
              Expanded(child: Text(step.instruction, style: const TextStyle(fontSize: 11, height: 1.2))),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _amenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('din') || lower.contains('food')) return Icons.restaurant;
    if (lower.contains('rest') || lower.contains('toilet')) return Icons.wc;
    if (lower.contains('shop') || lower.contains('mall')) return Icons.shopping_bag;
    if (lower.contains('surau') || lower.contains('prayer')) return Icons.mosque;
    if (lower.contains('petrol')) return Icons.local_gas_station;
    return lower.contains('cinema') ? Icons.movie : Icons.store;
  }
}
