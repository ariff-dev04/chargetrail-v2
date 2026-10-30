import 'package:flutter/material.dart';
import '../../domain/station_model.dart';

typedef StationModel = ChargingStation;

/// Brand resolver for Malaysian EV charging network operators.
class OperatorBrandTheme {
  final String tag;
  final String label;
  final Color color;
  final IconData icon;

  const OperatorBrandTheme({
    required this.tag,
    required this.label,
    required this.color,
    required this.icon,
  });

  static OperatorBrandTheme fromStation(ChargingStation station) {
    final t = '${station.name} ${station.operatorName ?? ''}'.toLowerCase();
    if (t.contains('tesla')) return const OperatorBrandTheme(tag: 'TSLA', label: 'Tesla', color: Color(0xFFE82127), icon: Icons.bolt_rounded);
    if (t.contains('gentari') || t.contains('petronas')) return const OperatorBrandTheme(tag: 'GTR', label: 'Gentari', color: Color(0xFF00A19C), icon: Icons.ev_station_rounded);
    if (t.contains('jomcharge') || t.contains('jom charge')) return const OperatorBrandTheme(tag: 'JOM', label: 'JomCharge', color: Color(0xFF1E88E5), icon: Icons.flash_on_rounded);
    if (t.contains('chargev') || t.contains('charginev')) return const OperatorBrandTheme(tag: 'CEV', label: 'ChargEV', color: Color(0xFF2E7D32), icon: Icons.eco_rounded);
    if (t.contains('shell')) return const OperatorBrandTheme(tag: 'SHL', label: 'Shell Recharge', color: Color(0xFFD97706), icon: Icons.bolt_rounded);
    if (t.contains('dc handal') || t.contains('dchandal')) return const OperatorBrandTheme(tag: 'DCH', label: 'DC Handal', color: Color(0xFFEA580C), icon: Icons.flash_on_rounded);
    if (t.contains('chargesini') || t.contains('charge sini')) return const OperatorBrandTheme(tag: 'CSN', label: 'ChargeSini', color: Color(0xFF7E57C2), icon: Icons.ev_station_rounded);
    if (t.contains('tnb') || t.contains('electron')) return const OperatorBrandTheme(tag: 'TNB', label: 'TNB Electron', color: Color(0xFF3949AB), icon: Icons.bolt_rounded);
    return const OperatorBrandTheme(tag: 'EV', label: 'Public EV', color: Color(0xFF0F766E), icon: Icons.ev_station_rounded);
  }
}

/// Custom high-contrast map marker with operator theme, gold ring tier, and monogram badge.
class OperatorMapMarker extends StatelessWidget {
  final ChargingStation station;
  final bool isSelected;
  final VoidCallback onTap;

  const OperatorMapMarker({
    super.key,
    required this.station,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OperatorBrandTheme.fromStation(station);
    final isUltra = station.maxPowerKw >= 100.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          scale: isSelected ? 1.22 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isSelected || isUltra) ? Colors.amber : Colors.white,
                    width: isSelected ? 2.8 : (isUltra ? 2.2 : 1.8),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(child: Icon(theme.icon, size: 17, color: Colors.white)),
              ),
              const SizedBox(height: 1.5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.color.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 0.8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                ),
                child: Text(
                  theme.tag,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand chip badge showing operator identity and kW charging speed tier.
class OperatorBrandChip extends StatelessWidget {
  final ChargingStation station;

  const OperatorBrandChip({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = OperatorBrandTheme.fromStation(station);
    final isDc = station.maxPowerKw >= 25.0 ||
        station.plugTypes.any((p) => p.type.toUpperCase().contains('DC') || p.type.toUpperCase().contains('CCS'));
    final speedTier = isDc ? 'DC ${station.maxPowerKw.toInt()}kW' : 'AC ${station.maxPowerKw.toInt()}kW';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: theme.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: 14, color: theme.color),
          const SizedBox(width: 5),
          Text(theme.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.color)),
          Text(' • $speedTier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.color)),
        ],
      ),
    );
  }
}
