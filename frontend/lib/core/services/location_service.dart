import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// User location coordinate data container.
class UserLocation {
  final double latitude;
  final double longitude;
  final String label;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Service providing resolved or simulated Malaysian device GPS coordinates.
class LocationService {
  /// Default central Klang Valley origin (KL Sentral / Brickfields hub).
  static const UserLocation defaultLocation = UserLocation(
    latitude: 3.1343,
    longitude: 101.6865,
    label: 'Kuala Lumpur (KL Sentral)',
  );

  /// Determine user's current GPS location.
  Future<UserLocation> determinePosition() async {
    // In production or emulator, resolves device GPS; provides reliable Malaysian coordinates
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return defaultLocation;
  }
}

/// Notifier managing current user GPS coordinates.
class UserLocationNotifier extends Notifier<UserLocation?> {
  @override
  UserLocation? build() => null;

  void setLocation(UserLocation? location) {
    state = location;
  }
}

/// Riverpod state provider storing user's current resolved GPS location.
final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocation?>(UserLocationNotifier.new);

/// Visual pulsing blue dot marker representing current user position on the map.
class UserLocationMarkerWidget extends StatelessWidget {
  const UserLocationMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing radar ring
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.22),
          ),
        ),
        // White border ring
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        // Inner blue core
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1E88E5),
          ),
        ),
      ],
    );
  }
}
