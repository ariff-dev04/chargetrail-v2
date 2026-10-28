import 'dart:math';
import 'package:dio/dio.dart';
import '../domain/station_model.dart';

/// Multi-source open EV charging discovery engine querying Nominatim and Photon Komoot POIs.
class OsmOverpassService {
  final Dio _dio;
  static final Set<String> _scannedCellCache = {};

  static const _osmHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'ChargeTrailV2/1.0 (https://github.com/ariff-dev04/chargetrail-v2)',
  };

  OsmOverpassService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  /// Backward compatible alias forwarding to multi-source discovery.
  Future<List<ChargingStation>> fetchViewportStations({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required List<ChargingStation> existingStations,
    bool forceRefresh = false,
  }) {
    return fetchStationsInBounds(
      centerLat: (minLat + maxLat) / 2.0,
      centerLng: (minLng + maxLng) / 2.0,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
      existingStations: existingStations,
      forceRefresh: forceRefresh,
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
    bool forceRefresh = false,
  }) async {
    // Spatial grid cache key (~0.05 degree / 5.5 km cells)
    final cellKey = '${(centerLat * 20).round()}_${(centerLng * 20).round()}';
    if (!forceRefresh && _scannedCellCache.contains(cellKey)) {
      return const [];
    }

    final allKnown = [...existingStations];

    bool isTooClose(double lat, double lng) {
      return allKnown.any((s) {
        final dLat = (s.latitude - lat) * 111.0;
        final dLon = (s.longitude - lng) * 111.0 * cos(lat * pi / 180.0);
        return sqrt(dLat * dLat + dLon * dLon) < 0.15;
      });
    }

    // Run Nominatim and Photon in parallel for maximum speed and zero Overpass timeouts
    final nominatimFuture = _fetchNominatim(
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
      isTooClose: isTooClose,
    );

    final photonFuture = _fetchPhoton(
      centerLat: centerLat,
      centerLng: centerLng,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
      isTooClose: isTooClose,
    );

    final results = await Future.wait([nominatimFuture, photonFuture]);
    final discovered = <ChargingStation>[];

    for (final list in results) {
      for (final st in list) {
        if (!isTooClose(st.latitude, st.longitude)) {
          discovered.add(st);
          allKnown.add(st);
        }
      }
    }

    if (discovered.isNotEmpty) {
      _scannedCellCache.add(cellKey);
    }

    return discovered;
  }

  /// Query OpenStreetMap Nominatim for charging stations bounded within viewbox.
  Future<List<ChargingStation>> _fetchNominatim({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required bool Function(double, double) isTooClose,
  }) async {
    final list = <ChargingStation>[];
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': 'charging_station',
          'format': 'jsonv2',
          'addressdetails': 1,
          'extratags': 1,
          'viewbox': '$minLng,$maxLat,$maxLng,$minLat',
          'bounded': 1,
          'limit': 40,
        },
        options: Options(headers: _osmHeaders),
      );

      if (res.statusCode == 200 && res.data is List) {
        for (final item in res.data as List) {
          final m = item as Map<String, dynamic>;
          final type = m['type']?.toString().toLowerCase();
          final category = m['category']?.toString().toLowerCase();
          if (type != 'charging_station' && category != 'amenity') continue;

          final rawLat = double.tryParse(m['lat']?.toString() ?? '') ?? 0.0;
          final rawLon = double.tryParse(m['lon']?.toString() ?? '') ?? 0.0;
          if (rawLat == 0.0 && rawLon == 0.0) continue;

          double cLat = rawLat;
          double cLon = rawLon;
          if (cLat.abs() > 90.0 && cLat.abs() <= 180.0 && cLon.abs() <= 90.0) {
            final temp = cLat;
            cLat = cLon;
            cLon = temp;
          }

          if (cLat < -90.0 || cLat > 90.0 || cLon < -180.0 || cLon > 180.0) continue;
          if (isTooClose(cLat, cLon)) continue;

          final addr = m['address'] as Map<String, dynamic>? ?? {};
          final extratags = m['extratags'] as Map<String, dynamic>? ?? {};

          final operator = extratags['operator']?.toString() ??
              extratags['brand']?.toString() ??
              extratags['network']?.toString() ??
              'OpenStreetMap Community';

          final city = addr['city']?.toString() ??
              addr['town']?.toString() ??
              addr['suburb']?.toString() ??
              addr['county']?.toString() ??
              addr['district']?.toString() ??
              'Peninsular Malaysia';
          final state = addr['state']?.toString() ?? 'Malaysia';
          final road = addr['road']?.toString() ?? addr['street']?.toString() ?? '';
          final displayName = m['display_name']?.toString() ?? (road.isNotEmpty ? '$road, $city' : city);

          final rawName = m['name']?.toString().trim() ?? '';
          String name;
          if (rawName.isEmpty ||
              rawName.toLowerCase() == 'charging station' ||
              rawName.toLowerCase() == 'ev charger') {
            final loc = road.isNotEmpty ? road : city;
            name = '$operator ($loc)';
          } else {
            name = rawName;
          }

          final parking = _classifyParkingLevel(extratags, name);

          final plugs = <PlugInfo>[];
          if (extratags['socket:type2'] != null || extratags['socket:type2_combo'] != null) {
            plugs.add(const PlugInfo(type: 'Type 2', powerKw: 22.0, count: 2));
          }
          if (extratags['socket:chademo'] != null) {
            plugs.add(const PlugInfo(type: 'CHAdeMO', powerKw: 50.0, count: 1));
          }
          if (plugs.isEmpty || extratags['socket:type2_combo'] != null) {
            plugs.add(const PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2));
          }

          final station = ChargingStation(
            id: 'nom-${m['place_id'] ?? m['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}_${list.length}',
            name: name,
            operatorName: operator,
            address: displayName,
            city: city,
            state: state,
            latitude: cLat,
            longitude: cLon,
            plugTypes: plugs,
            maxPowerKw: 60.0,
            isAvailable: true,
            is24Hours: true,
            chargingCostMyr: 1.40,
            parkingFeeMyr: 0.0,
            parkingLevel: parking,
            operationHours: extratags['opening_hours']?.toString() ?? '24 Hours',
            amenities: const ['Convenience Store', 'Restroom'],
            howToAccess: const [
              AccessStep(stepNumber: 1, instruction: 'Located via OpenStreetMap open index.'),
            ],
            rating: 4.5,
            reviewCount: 3,
            source: 'osm_live',
            isVerified: true,
          );
          list.add(station);
        }
      }
    } catch (_) {}
    return list;
  }

  /// Query Photon Komoot with bounded bbox for EV brand keywords in parallel.
  Future<List<ChargingStation>> _fetchPhoton({
    required double centerLat,
    required double centerLng,
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required bool Function(double, double) isTooClose,
  }) async {
    const queries = [
      'charging station',
      'Gentari',
      'JomCharge',
      'ChargEV',
      'DC Handal',
      'Shell Recharge',
      'TNB Electron',
    ];

    final list = <ChargingStation>[];

    Future<void> searchKeyword(String q) async {
      try {
        final res = await _dio.get(
          'https://photon.komoot.io/api/',
          queryParameters: {
            'q': q,
            'lat': centerLat,
            'lon': centerLng,
            'bbox': '$minLng,$minLat,$maxLng,$maxLat',
            'limit': 20,
          },
        );

        if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
          final features = res.data['features'] as List<dynamic>? ?? [];
          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final osmValue = (props['osm_value'] ?? '').toString().toLowerCase();
            final osmKey = (props['osm_key'] ?? '').toString().toLowerCase();

            // Strict filter: only real EV chargers
            final isEv = osmValue == 'charging_station' ||
                (osmKey == 'man_made' && osmValue == 'charge_point');
            if (!isEv) continue;

            final coords = f['geometry']?['coordinates'] as List<dynamic>? ?? [];
            if (coords.length < 2) continue;

            double cLon = (coords[0] as num).toDouble();
            double cLat = (coords[1] as num).toDouble();
            if (cLat.abs() > 90.0 && cLat.abs() <= 180.0 && cLon.abs() <= 90.0) {
              final temp = cLat;
              cLat = cLon;
              cLon = temp;
            }

            if (cLat < -90.0 || cLat > 90.0 || cLon < -180.0 || cLon > 180.0) continue;
            if (isTooClose(cLat, cLon)) continue;

            final rawName = (props['name']?.toString() ?? 'EV Charger').trim();
            final city = props['city']?.toString() ??
                props['county']?.toString() ??
                props['state']?.toString() ??
                'Peninsular Malaysia';
            final street = props['street']?.toString() ?? '';

            // Enrich generic names with street or city
            String name;
            const genericNames = [
              'gentari',
              'ev charger',
              'charging station',
              'charg',
              'jomcharge',
              'chargev',
              'dc handal',
              'shell recharge',
              'tnb electron',
            ];
            if (genericNames.contains(rawName.toLowerCase())) {
              final locTag = street.isNotEmpty ? street : city;
              name = '$rawName ($locTag)';
            } else {
              name = rawName;
            }

            final parking = _classifyParkingLevel(props, name);

            final station = ChargingStation(
              id: 'photon-${props['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}_${list.length}',
              name: name,
              operatorName: props['operator']?.toString() ??
                  props['brand']?.toString() ??
                  'Open POI Network',
              address: street.isNotEmpty ? '$street, $city' : city,
              city: city,
              state: props['state']?.toString() ?? 'Malaysia',
              latitude: cLat,
              longitude: cLon,
              plugTypes: const [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2)],
              maxPowerKw: 60.0,
              isAvailable: true,
              is24Hours: true,
              chargingCostMyr: 1.40,
              parkingFeeMyr: 0.0,
              parkingLevel: parking,
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
            list.add(station);
          }
        }
      } catch (_) {}
    }

    await Future.wait(queries.map(searchKeyword));
    return list;
  }

  static String _classifyParkingLevel(Map<String, dynamic> tags, String name) {
    final text =
        '${name.toLowerCase()} ${(tags['parking'] ?? '').toString().toLowerCase()} ${(tags['location'] ?? '').toString().toLowerCase()} ${(tags['covered'] ?? '').toString().toLowerCase()} ${(tags['level'] ?? '').toString().toLowerCase()}';

    if (text.contains('mall') ||
        text.contains('plaza') ||
        text.contains('klcc') ||
        text.contains('pavilion') ||
        text.contains('basement') ||
        text.contains('multi-storey') ||
        text.contains('underground') ||
        text.contains('indoor')) {
      return 'Multi-Storey / Indoor Carpark';
    }

    if (text.contains('r&r') ||
        text.contains('rsa') ||
        text.contains('layby') ||
        text.contains('shell') ||
        text.contains('petronas') ||
        text.contains('caltex') ||
        text.contains('surface')) {
      return 'Highway R&R / Open Bay';
    }

    return 'Open Public Bay';
  }
}
