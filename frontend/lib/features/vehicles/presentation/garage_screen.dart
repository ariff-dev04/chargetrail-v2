import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle_model.dart';
import 'vehicle_controller.dart';

/// Screen managing multi-vehicle EV garage, active vehicle selection, and SoC battery telemetry.
class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleControllerProvider);
    final active = state.activeVehicle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Garage & Battery Telemetry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Vehicle',
            onPressed: () => _showAddVehicleSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Active EV Telemetry Hero Card (KF11)
          _buildActiveVehicleHero(context, active, state.simulatedCurrentSoc, isDark),
          const SizedBox(height: 20),

          // 2. My EV Garage List (KF12)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'My EV Garage (${state.garageVehicles.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddVehicleSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add EV'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...state.garageVehicles.map((v) => _buildGarageVehicleCard(v, isDark)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActiveVehicleHero(
    BuildContext context,
    VehicleProfile active,
    int currentSoc,
    bool isDark,
  ) {
    final notifier = ref.read(vehicleControllerProvider.notifier);
    final totalRange = active.rangeAtSocKm(currentSoc);
    final safeRange = active.safeUsableRangeAtSocKm(currentSoc);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${active.batteryCapacityKwh} kWh • ${active.maxDcChargeKw.toInt()} kW DC Peak • ${active.connectorType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Active EV',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Battery SoC Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      currentSoc > 20 ? Icons.battery_charging_full : Icons.battery_alert,
                      color: currentSoc > 20 ? AppTheme.primaryTeal : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Current Battery SoC:',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentSoc%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
              ),
            ],
          ),
          Slider(
            value: currentSoc.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            activeColor: AppTheme.primaryTeal,
            onChanged: (v) => notifier.setSimulatedSoc(v.round()),
          ),

          // Range Physics Metrics
          Row(
            children: [
              _buildRangeMetric(
                'Total Range at $currentSoc%',
                '${totalRange.toInt()} km',
                Icons.speed,
                Colors.blue[700]!,
              ),
              const SizedBox(width: 12),
              _buildRangeMetric(
                'Safe Route Range (${active.reserveSocPercent}% reserve)',
                '${safeRange.toInt()} km',
                Icons.shield,
                AppTheme.primaryTeal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGarageVehicleCard(VehicleProfile vehicle, bool isDark) {
    final notifier = ref.read(vehicleControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: vehicle.isPrimary
              ? AppTheme.primaryTeal.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(
            Icons.electric_car,
            color: vehicle.isPrimary ? AppTheme.primaryTeal : Colors.grey,
          ),
        ),
        title: Text(
          vehicle.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${vehicle.batteryCapacityKwh} kWh • ${vehicle.usableRangeKm.toInt()} km • ${vehicle.connectorType} • Reserve: ${vehicle.reserveSocPercent}%',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!vehicle.isPrimary)
              TextButton(
                onPressed: () => notifier.setPrimaryVehicle(vehicle.id),
                child: const Text('Set Active'),
              )
            else
              const Icon(Icons.check_circle, color: AppTheme.primaryTeal, size: 20),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => notifier.deleteVehicle(vehicle.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddVehicleModal(),
    );
  }
}

class _AddVehicleModal extends ConsumerWidget {
  const _AddVehicleModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = VehicleRepository.defaultPresets;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.40,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              const Text(
                'Add Vehicle to Garage (KF11)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select from verified Malaysian EV presets or add a custom model.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...presets.map((preset) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.electric_car, color: AppTheme.primaryTeal),
                    title: Text('${preset.brand} ${preset.modelName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${preset.batteryCapacityKwh} kWh • ${preset.usableRangeKm.toInt()} km • ${preset.maxDcChargeKw.toInt()} kW DC', style: const TextStyle(fontSize: 11)),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        ref.read(vehicleControllerProvider.notifier).addVehicleFromPreset(preset);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Add', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
