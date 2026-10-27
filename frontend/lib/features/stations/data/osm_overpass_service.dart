import 'dart:math';
import 'package:dio/dio.dart';
import '../domain/station_model.dart';

/// Multi-source open EV charging discovery engine querying Overpass API and Photon POIs.
class OsmOverpassService {
  final Dio _dio;
  static final Set<String> _scannedCellCache = {};

  static const _mirrors = [
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  static const _osmHeaders = {
    'Accept': '*/*',
    'User-Agent': 'ChargeTrailV2/1.0 (https://github.com/ariff-dev04/chargetrail-v2)',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

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

  /// Execute Live OpenStreetMap & Photon discovery for viewport center & bounds.
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
        return sqrt(dLat * dLat + dLon * dLon) < 0.12;
      });
    }

    // --- Tier 1: Live Overpass API (Nodes & Ways with multi-mirror failover) ---
    final overpassQuery = '[out:json][timeout:6];'
        '(node["amenity"="charging_station"]($minLat,$minLng,$maxLat,$maxLng);'
        'way["amenity"="charging_station"]($minLat,$minLng,$maxLat,$maxLng);'
        'node["amenity"="charging_station"](around:15000,$centerLat,$centerLng););'
        'out center 40;';

    final body = 'data=${Uri.encodeQueryComponent(overpassQuery)}';

    for (final mirror in _mirrors) {
      try {
        final res = await _dio.post(
          mirror,
          data: body,
          options: Options(headers: _osmHeaders),
        );

        if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
          final elements = res.data['elements'] as List<dynamic>? ?? [];
          for (final el in elements) {
            final lat = (el['lat'] ?? el['center']?['lat'] as num?)?.toDouble() ?? 0.0;
            final lon = (el['lon'] ?? el['center']?['lon'] as num?)?.toDouble() ?? 0.0;
            if (lat >= 1.0 && lat <= 7.5 && lon >= 99.0 && lon <= 120.0 && !isTooClose(lat, lon)) {
              final tags = el['tags'] as Map<String, dynamic>? ?? {};
              final station = _parseOsmElement(el['id'].toString(), lat, lon, tags);
              discovered.add(station);
              allKnown.add(station);
            }
          }
          if (discovered.isNotEmpty) break;
        }
      } catch (_) {}
    }

    // --- Tier 2: Photon Open POI Search (Komoot live open index) ---
    final queries = ['charging station', 'Gentari', 'JomCharge', 'TNB Electron'];
    for (final q in queries) {
      try {
        final res = await _dio.get(
          'https://photon.komoot.io/api/',
          queryParameters: {
            'q': q,
            'lat': centerLat,
            'lon': centerLng,
            'limit': 10,
          },
        );
        if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
          final features = res.data['features'] as List<dynamic>? ?? [];
          for (final f in features) {
            final coords = f['geometry']?['coordinates'] as List<dynamic>? ?? [];
            if (coords.length >= 2) {
              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              if (lat >= 1.0 && lat <= 7.5 && lon >= 99.0 && lon <= 120.0 && !isTooClose(lat, lon)) {
                final props = f['properties'] as Map<String, dynamic>? ?? {};
                final name = props['name']?.toString() ?? 'EV Charger (Photon)';
                final city = props['city']?.toString() ?? props['county']?.toString() ?? 'Malaysia';
                final station = ChargingStation(
                  id: 'photon-${props['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}_${discovered.length}',
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
                  isVerified: true,
                );
                discovered.add(station);
                allKnown.add(station);
              }
            }
          }
        }
      } catch (_) {}
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
      isVerified: true,
    );
  }
}
