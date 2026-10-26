import 'dart:math';
import 'package:dio/dio.dart';
import '../domain/station_model.dart';
import 'malaysia_ev_registry.dart';

/// Multi-source open EV charging discovery engine combining Overpass API, Photon POIs, and Open Registry.
class OsmOverpassService {
  final Dio _dio;
  static final Set<String> _scannedCellCache = {};

  OsmOverpassService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  /// Backward compatible alias forwarding to multi-source discovery.
  Future<List<ChargingStation>> fetchViewportStations({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required List<ChargingStation> existingStations,
  }) {
    return fetchStationsInBounds(
      centerLat: (minLat + maxLat) / 2.0,
      centerLng: (minLng + maxLng) / 2.0,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
      existingStations: existingStations,
    );
  }

  /// Execute 3-Tier Open Discovery Strategy for viewport center & bounds.
  Future<List<ChargingStation>> fetchStationsInBounds({
    required double centerLat,
    required double centerLng,
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required List<ChargingStation> existingStations,
  }) async {
    // Spatial grid cache key (~0.05 degree / 5.5 km cells)
    final cellKey = '${(centerLat * 20).round()}_${(centerLng * 20).round()}';
    if (_scannedCellCache.contains(cellKey)) {
      return const [];
    }
    _scannedCellCache.add(cellKey);

    final discovered = <ChargingStation>[];
    final allKnown = [...existingStations];

    bool isTooClose(double lat, double lng) {
      return allKnown.any((s) {
        final dLat = (s.latitude - lat) * 111.0;
        final dLon = (s.longitude - lng) * 111.0 * cos(lat * pi / 180.0);
        return sqrt(dLat * dLat + dLon * dLon) < 0.15;
      });
    }

    // --- Tier 1: Live Overpass API (Both Nodes & Ways around:15000m) ---
    try {
      final overpassQuery = '[out:json][timeout:6];'
          '(node["amenity"="charging_station"](around:15000,$centerLat,$centerLng);'
          'way["amenity"="charging_station"](around:15000,$centerLat,$centerLng););'
          'out center 40;';

      final res = await _dio.get(
        'https://overpass-api.de/api/interpreter',
        queryParameters: {'data': overpassQuery},
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final elements = res.data['elements'] as List<dynamic>? ?? [];
        for (final el in elements) {
          final lat = (el['lat'] ?? el['center']?['lat'] as num?)?.toDouble() ?? 0.0;
          final lon = (el['lon'] ?? el['center']?['lon'] as num?)?.toDouble() ?? 0.0;
          if (lat != 0.0 && lon != 0.0 && !isTooClose(lat, lon)) {
            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final station = _parseOsmElement(el['id'].toString(), lat, lon, tags);
            discovered.add(station);
            allKnown.add(station);
          }
        }
      }
    } catch (_) {}

    // --- Tier 2: Photon Open POI Search ---
    try {
      final res = await _dio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q': 'charging station',
          'lat': centerLat,
          'lon': centerLng,
          'limit': 15,
        },
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final features = res.data['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          final coords = f['geometry']?['coordinates'] as List<dynamic>? ?? [];
          if (coords.length >= 2) {
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            if (lat >= 1.0 && lat <= 7.5 && lon >= 99.0 && lon <= 119.5 && !isTooClose(lat, lon)) {
              final props = f['properties'] as Map<String, dynamic>? ?? {};
              final name = props['name']?.toString() ?? 'EV Charger (Photon)';
              final city = props['city']?.toString() ?? props['county']?.toString() ?? 'Malaysia';
              final station = ChargingStation(
                id: 'photon-${props['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}',
                name: name,
                operatorName: 'Open POI Network',
                address: '${props['street'] ?? name}, $city',
                city: city,
                state: props['state']?.toString() ?? 'Malaysia',
                latitude: lat,
                longitude: lon,
                plugTypes: const [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2)],
                maxPowerKw: 60.0,
                isAvailable: true,
                is24Hours: true,
                chargingCostMyr: 1.40,
                parkingFeeMyr: 0.0,
                parkingLevel: 'Ground / Open Bay',
                operationHours: '24 Hours',
                amenities: const ['Convenience Store', 'Dining'],
                howToAccess: const [
                  AccessStep(stepNumber: 1, instruction: 'Located via open POI geographic index.'),
                ],
                rating: 4.5,
                reviewCount: 4,
                source: 'osm_live',
                isVerified: false,
              );
              discovered.add(station);
              allKnown.add(station);
            }
          }
        }
      }
    } catch (_) {}

    // --- Tier 3: Curated Regional Malaysia Open EV Registry ---
    final regionalStations = MalaysiaEvRegistry.getStationsNear(centerLat, centerLng, radiusKm: 35.0);
    for (final reg in regionalStations) {
      if (!isTooClose(reg.latitude, reg.longitude)) {
        discovered.add(reg);
        allKnown.add(reg);
      }
    }

    return discovered;
  }

  ChargingStation _parseOsmElement(
    String id,
    double lat,
    double lon,
    Map<String, dynamic> tags,
  ) {
    final name = tags['name']?.toString() ?? tags['operator']?.toString() ?? 'EV Charger (OSM Live)';
    final operator = tags['operator']?.toString() ?? 'OpenStreetMap Community';
    final city = tags['addr:city']?.toString() ?? 'Peninsular Malaysia';
    final state = tags['addr:state']?.toString() ?? 'Malaysia';
    final street = tags['addr:street']?.toString() ?? 'Public Road';

    final plugs = <PlugInfo>[];
    if (tags['socket:type2'] != null || tags['socket:type2_combo'] != null) {
      plugs.add(const PlugInfo(type: 'Type 2', powerKw: 22.0, count: 2));
    }
    if (tags['socket:chademo'] != null) {
      plugs.add(const PlugInfo(type: 'CHAdeMO', powerKw: 50.0, count: 1));
    }
    if (plugs.isEmpty || tags['socket:type2_combo'] != null) {
      plugs.add(const PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2));
    }

    final maxPower = plugs.map((p) => p.powerKw).fold(0.0, max);
    final hours = tags['opening_hours']?.toString() ?? '24 Hours';
    final is24h = hours.toLowerCase().contains('24/7') || hours.toLowerCase().contains('24');

    return ChargingStation(
      id: 'osm-$id',
      name: name,
      operatorName: operator,
      address: '$street, $city',
      city: city,
      state: state,
      latitude: lat,
      longitude: lon,
      plugTypes: plugs,
      maxPowerKw: maxPower > 0 ? maxPower : 60.0,
      isAvailable: true,
      is24Hours: is24h,
      chargingCostMyr: 1.40,
      parkingFeeMyr: 0.0,
      parkingLevel: 'Street / Open Carpark',
      operationHours: hours,
      amenities: const ['Convenience Store', 'Restroom'],
      howToAccess: const [
        AccessStep(stepNumber: 1, instruction: 'Located from live OpenStreetMap community network.'),
      ],
      rating: 4.5,
      reviewCount: 3,
      source: 'osm_live',
      isVerified: false,
    );
  }
}
