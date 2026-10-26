import 'dart:math';
import 'package:dio/dio.dart';
import '../domain/station_model.dart';

/// Service performing lazy OpenStreetMap Overpass live charging station discovery.
class OsmOverpassService {
  final Dio _dio;
  static final Set<String> _scannedCellCache = {};

  OsmOverpassService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://overpass-api.de/api',
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  /// Fetch live OSM EV stations within current viewport bounding box.
  Future<List<ChargingStation>> fetchViewportStations({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required List<ChargingStation> existingStations,
  }) async {
    // Generate spatial grid cell key (rounded to 0.05 degrees ~5.5 km)
    final cellKey = '${(minLat * 20).floor()}_${(minLng * 20).floor()}_'
        '${(maxLat * 20).ceil()}_${(maxLng * 20).ceil()}';

    if (_scannedCellCache.contains(cellKey)) {
      return const [];
    }
    _scannedCellCache.add(cellKey);

    final query = '[out:json][timeout:5];'
        'node["amenity"="charging_station"]($minLat,$minLng,$maxLat,$maxLng);'
        'out body;';

    try {
      final res = await _dio.get('/interpreter', queryParameters: {'data': query});
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final elements = res.data['elements'] as List<dynamic>? ?? [];
        final newStations = <ChargingStation>[];

        for (final el in elements) {
          final lat = (el['lat'] as num?)?.toDouble() ?? 0.0;
          final lon = (el['lon'] as num?)?.toDouble() ?? 0.0;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};

          // Deduplicate against existing stations within 150 meters
          final isDuplicate = existingStations.any((s) {
            final dLat = (s.latitude - lat) * 111.0;
            final dLon = (s.longitude - lon) * 111.0 * cos(lat * pi / 180.0);
            return sqrt(dLat * dLat + dLon * dLon) < 0.15;
          });

          if (!isDuplicate) {
            newStations.add(_parseOsmElement(el['id'].toString(), lat, lon, tags));
          }
        }
        return newStations;
      }
    } catch (_) {}

    return const [];
  }

  ChargingStation _parseOsmElement(
    String id,
    double lat,
    double lon,
    Map<String, dynamic> tags,
  ) {
    final name = tags['name']?.toString() ??
        tags['operator']?.toString() ??
        'EV Charger (OSM Live)';
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
        AccessStep(
          stepNumber: 1,
          instruction: 'Located from live OpenStreetMap community network.',
        ),
      ],
      rating: 4.5,
      reviewCount: 3,
      source: 'osm_live',
      isVerified: false,
    );
  }
}
