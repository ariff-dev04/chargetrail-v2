import 'package:flutter/material.dart';

/// Reusable driver advisory and open-data disclaimer banner for EV highway routing.
class RouteAdvisoryBanner extends StatelessWidget {
  final bool compact;

  const RouteAdvisoryBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amberColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFD97706);
    final bgColor = isDark
        ? const Color(0xFF422006).withValues(alpha: 0.35)
        : const Color(0xFFFFFBEB);
    final borderColor = isDark
        ? const Color(0xFFB45309).withValues(alpha: 0.5)
        : const Color(0xFFFDE68A);

    if (compact) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: amberColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Verify Carriageway Direction: Check exact highway R&R direction '
                '(Northbound/Utara vs Southbound/Selatan) and toll/U-turn geometry in Google Maps or Waze before driving.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: amberColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Driver Advisory & Open-Data Disclaimer: Route stops and R&R directions '
              'are calculated from live OpenStreetMap & community telemetry. Always verify '
              'highway carriageway direction (Northbound/Utara vs Southbound/Selatan) and '
              'parking access rules before exiting. Tap \'Swap Stop\' on any stop tile to switch chargers.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
