import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../community/presentation/widgets/micro_survey_card.dart';
import '../../domain/station_model.dart';

/// Modal detail sheet showing tariffs, parking level, plugs, and access steps.
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
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Operator, Verified & Bookmark Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      station.operatorName ?? 'Community Station',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                    ),
                  ),
                  if (station.isVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, size: 16, color: Colors.blue),
                    const SizedBox(width: 2),
                    const Text('Verified', style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(authControllerProvider).currentUser;
                      final isSaved = user?.isBookmarked(station.id) ?? false;
                      return IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? AppTheme.primaryTeal : Colors.grey,
                          size: 22,
                        ),
                        onPressed: () => ref.read(authControllerProvider.notifier).toggleBookmark(station.id),
                      );
                    },
                  ),
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${station.rating.toStringAsFixed(1)} (${station.reviewCount})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Station Name & Availability Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: station.isAvailable
                          ? AppTheme.successGreen.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      station.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: station.isAvailable ? AppTheme.successGreen : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                station.address,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              _buildPricingCard(isDark),
              const SizedBox(height: 16),

              Text('Available Connectors', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildPlugs(isDark),
              const SizedBox(height: 16),

              if (station.howToAccess.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.navigation, size: 18, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Text('How to Access Charger', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSteps(),
                const SizedBox(height: 16),
              ],

              if (station.amenities.isNotEmpty) ...[
                Text('Nearby Amenities', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: station.amenities.map((a) {
                    return Chip(
                      avatar: Icon(_amenityIcon(a), size: 14),
                      label: Text(a, style: const TextStyle(fontSize: 12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Survei Mikro & Driver Reviews (Module 3)
              const Divider(height: 24),
              MicroSurveyCard(stationId: station.id),
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: onNavigatePressed ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.directions),
                label: const Text('Navigate to Station'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D28) : const Color(0xFFF1F8F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2C3E36) : const Color(0xFFD4ECE1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _infoCol(
                'Charging Tariff',
                station.chargingCostMyr > 0 ? 'RM ${station.chargingCostMyr.toStringAsFixed(2)} / kWh' : 'Free Charging',
                Icons.electric_bolt,
                AppTheme.primaryTeal,
              ),
              const SizedBox(width: 16),
              _infoCol(
                'Parking Fee',
                station.parkingFeeMyr > 0 ? 'RM ${station.parkingFeeMyr.toStringAsFixed(2)}' : 'Free Entry',
                Icons.local_parking,
                Colors.orange[700]!,
              ),
            ],
          ),
          if (station.parkingLevel != null && station.parkingLevel!.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: [
                const Icon(Icons.layers, size: 16, color: AppTheme.primaryTeal),
                const SizedBox(width: 6),
                const Text('Parking Level: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(
                    station.parkingLevel!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlugs(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: station.plugTypes.map((plug) {
        final isFast = plug.powerKw >= 120.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23322D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isFast ? AppTheme.ultraFastColor : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ev_station, size: 18, color: isFast ? AppTheme.ultraFastColor : AppTheme.primaryTeal),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plug.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${plug.powerKw.toInt()} kW • ${plug.count} bays', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryTeal,
                child: Text('${step.stepNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(step.instruction, style: const TextStyle(fontSize: 13, height: 1.3))),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _amenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('dining') || lower.contains('food')) return Icons.restaurant;
    if (lower.contains('restroom') || lower.contains('toilet')) return Icons.wc;
    if (lower.contains('shopping') || lower.contains('mall')) return Icons.shopping_bag;
    if (lower.contains('surau') || lower.contains('prayer')) return Icons.mosque;
    if (lower.contains('petrol')) return Icons.local_gas_station;
    if (lower.contains('cinema')) return Icons.movie;
    return Icons.store;
  }
}
