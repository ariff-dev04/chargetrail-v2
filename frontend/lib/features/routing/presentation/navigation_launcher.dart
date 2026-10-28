import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/route_models.dart';

/// Utilities for launching turn-by-turn navigation in external mapping applications.
class NavigationLauncher {
  /// Builds Google Maps universal directions URL with intermediate charging waypoints.
  static String buildGoogleMapsMultiStopUrl({
    required RoutePlanResult plan,
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
  }) {
    final originParam =
        '${origin.latitude.toStringAsFixed(6)},${origin.longitude.toStringAsFixed(6)}';
    final destParam =
        '${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}';

    final baseUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$originParam'
        '&destination=$destParam&travelmode=driving';

    if (plan.recommendedStops.isEmpty) return baseUrl;

    final waypointsStr = plan.recommendedStops
        .map((s) =>
            '${s.station.latitude.toStringAsFixed(6)},${s.station.longitude.toStringAsFixed(6)}')
        .join('|');

    return '$baseUrl&waypoints=${Uri.encodeComponent(waypointsStr)}';
  }

  /// Builds Google Maps single-destination directions URL using exact coordinates.
  static String buildGoogleMapsSingleUrl(
    double lat,
    double lng, {
    String? stationName,
    String? city,
  }) {
    final destParam = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    return 'https://www.google.com/maps/dir/?api=1&destination=$destParam&travelmode=driving';
  }

  /// Builds Waze turn-by-turn navigation deep-link URL.
  static String buildWazeUrl(double lat, double lng) {
    return 'https://waze.com/ul?ll=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}&navigate=yes';
  }

  /// Safely launches an external navigation URL with graceful fallback.
  static Future<bool> launchNavigationUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open map app. Link: $urlString'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching navigation: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  /// Convenient helper to open the navigation chooser for a station.
  static void showStationNavigationSheet(BuildContext context, dynamic station) {
    showStopNavigationPicker(
      context,
      stationName: station.name as String,
      lat: (station.latitude as num).toDouble(),
      lng: (station.longitude as num).toDouble(),
      city: station.city as String?,
    );
  }

  /// Shows choice dialog for full journey navigation (Google Maps vs Waze).
  static void showJourneyNavigationPicker(
    BuildContext context, {
    required RoutePlanResult plan,
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
  }) {
    final nextTargetLat = plan.recommendedStops.isNotEmpty
        ? plan.recommendedStops.first.station.latitude
        : destination.latitude;
    final nextTargetLng = plan.recommendedStops.isNotEmpty
        ? plan.recommendedStops.first.station.longitude
        : destination.longitude;
    final nextTargetName = plan.recommendedStops.isNotEmpty
        ? 'Stop 1: ${plan.recommendedStops.first.station.name}'
        : destination.name;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car, color: AppTheme.primaryTeal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Start Journey Navigation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.recommendedStops.isNotEmpty
                      ? 'Route includes ${plan.recommendedStops.length} recommended charging stop(s).'
                      : 'Direct route to ${destination.name}.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF4285F4),
                      child: Icon(Icons.map, color: Colors.white, size: 20),
                    ),
                    title: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      plan.recommendedStops.isNotEmpty
                          ? 'Full multi-stop route with all ${plan.recommendedStops.length} charging waypoints'
                          : 'Turn-by-turn driving directions to destination',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      final url = buildGoogleMapsMultiStopUrl(
                        plan: plan,
                        origin: origin,
                        destination: destination,
                      );
                      launchNavigationUrl(context, url);
                    },
                  ),
                ),
                const Divider(),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF33CCFF),
                      child: Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                    title: const Text('Waze', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Navigate to next leg ($nextTargetName)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      final url = buildWazeUrl(nextTargetLat, nextTargetLng);
                      launchNavigationUrl(context, url);
                    },
                  ),
                ),
                _buildDisclaimerBox(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows choice dialog for navigating to an individual charging stop.
  static void showStopNavigationPicker(
    BuildContext context, {
    required String stationName,
    required double lat,
    required double lng,
    String? city,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: AppTheme.primaryTeal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Navigate to $stationName',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF4285F4),
                      child: Icon(Icons.map, color: Colors.white, size: 20),
                    ),
                    title: const Text('Google Maps'),
                    subtitle: const Text('Turn-by-turn route to station', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchNavigationUrl(
                        context,
                        buildGoogleMapsSingleUrl(lat, lng, stationName: stationName, city: city),
                      );
                    },
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF33CCFF),
                      child: Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                    title: const Text('Waze'),
                    subtitle: const Text('Turn-by-turn route to station', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchNavigationUrl(context, buildWazeUrl(lat, lng));
                    },
                  ),
                ),
                _buildDisclaimerBox(),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildDisclaimerBox() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primaryTeal),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Disclaimer: Route & charger locations are sourced from open community data (OpenStreetMap). Always verify highway direction (Northbound/Southbound R&R), charger availability, and parking access rules before navigating.',
              style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
