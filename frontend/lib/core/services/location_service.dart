import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

/// Service providing physical device GPS coordinates and reverse geocoding.
class LocationService {
  final Dio _dio;

  LocationService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(milliseconds: 2500),
                receiveTimeout: const Duration(milliseconds: 2500),
                headers: {'User-Agent': 'my.ukm.chargetrail.v2'},
              ),
            );

  /// Default central Klang Valley origin (KL Sentral / Brickfields hub).
  static const UserLocation defaultLocation = UserLocation(
    latitude: 3.1343,
    longitude: 101.6865,
    label: 'Kuala Lumpur (KL Sentral)',
  );

  /// Determine user's real hardware GPS location with graceful fallback.
  Future<UserLocation> determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return defaultLocation;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return defaultLocation;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 4)),
      );

      final geo = await reverseGeocode(pos.latitude, pos.longitude);
      final label = geo['city'] != null && geo['city']!.isNotEmpty
          ? '${geo['city']}, ${geo['state'] ?? 'Malaysia'}'
          : 'My Location';

      return UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: label,
      );
    } catch (_) {
      return defaultLocation;
    }
  }

  /// Reverse geocode coordinates to Malaysian city, state, and address.
  Future<Map<String, String>> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'format': 'jsonv2', 'lat': lat, 'lon': lng},
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final city = addr['city'] ??
            addr['town'] ??
            addr['municipality'] ??
            addr['suburb'] ??
            addr['county'] ??
            '';
        final state = addr['state'] ?? 'Malaysia';
        final display = data['display_name'] as String? ?? '';

        return {
          'city': city.toString(),
          'state': state.toString(),
          'address': display,
        };
      }
    } catch (_) {}

    return _fallbackNearestMalaysianCity(lat, lng);
  }

  Map<String, String> _fallbackNearestMalaysianCity(double lat, double lng) {
    const cities = [
      {'city': 'Kuala Lumpur', 'state': 'Wilayah Persekutuan', 'lat': 3.1390, 'lng': 101.6869},
      {'city': 'Petaling Jaya', 'state': 'Selangor', 'lat': 3.1073, 'lng': 101.6067},
      {'city': 'Cyberjaya', 'state': 'Selangor', 'lat': 2.9213, 'lng': 101.6559},
      {'city': 'Putrajaya', 'state': 'Putrajaya', 'lat': 2.9264, 'lng': 101.6964},
      {'city': 'Seremban', 'state': 'Negeri Sembilan', 'lat': 2.7258, 'lng': 101.9424},
      {'city': 'Melaka', 'state': 'Melaka', 'lat': 2.1896, 'lng': 102.2501},
      {'city': 'Johor Bahru', 'state': 'Johor', 'lat': 1.4927, 'lng': 103.7414},
      {'city': 'Ipoh', 'state': 'Perak', 'lat': 4.5975, 'lng': 101.0901},
      {'city': 'George Town (Penang)', 'state': 'Penang', 'lat': 5.4164, 'lng': 100.3327},
      {'city': 'Kuantan', 'state': 'Pahang', 'lat': 3.8077, 'lng': 103.3260},
      {'city': 'Genting Highlands', 'state': 'Pahang', 'lat': 3.4237, 'lng': 101.7932},
    ];

    var closest = cities.first;
    var minD = double.infinity;

    for (final c in cities) {
      final cLat = c['lat'] as double;
      final cLng = c['lng'] as double;
      final d = pow(lat - cLat, 2) + pow(lng - cLng, 2);
      if (d < minD) {
        minD = d.toDouble();
        closest = c;
      }
    }

    final city = closest['city'] as String;
    final state = closest['state'] as String;
    return {
      'city': city,
      'state': state,
      'address': '$city, $state, Malaysia',
    };
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
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.22),
          ),
        ),
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
