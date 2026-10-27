import 'dart:math';
import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:latlong2/latlong.dart';
import '../../stations/data/station_local_cache.dart';
import '../../stations/domain/station_model.dart';
import '../../vehicles/domain/vehicle_model.dart';
import '../domain/route_models.dart';
import 'malaysian_places_catalog.dart';
class RouteRepository {
  final Dio _dio;
  RouteRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );
  static List<PlaceSuggestion> get defaultHubs => const [
        PlaceSuggestion(
          name: 'Kuala Lumpur (KLCC)',
          city: 'Kuala Lumpur',
          state: 'Kuala Lumpur',
          latitude: 3.1578,
          longitude: 101.7118,
          category: 'mall',
        ),
        PlaceSuggestion(
          name: 'Penang (Gurney Plaza)',
          city: 'George Town',
          state: 'Penang',
          latitude: 5.4372,
          longitude: 100.3096,
          category: 'mall',
        ),
        PlaceSuggestion(
          name: 'Putrajaya (IOI City Mall)',
          city: 'Putrajaya',
          state: 'Putrajaya',
          latitude: 2.9698,
          longitude: 101.7135,
          category: 'mall',
        ),
        PlaceSuggestion(
          name: 'Johor Bahru (Mid Valley Southkey)',
          city: 'Johor Bahru',
          state: 'Johor',
          latitude: 1.4989,
          longitude: 103.7774,
          category: 'mall',
        ),
        PlaceSuggestion(
          name: 'Tapah RSA (North-South Highway)',
          city: 'Tapah',
          state: 'Perak',
          latitude: 4.3138,
          longitude: 101.2582,
          category: 'highway_rsa',
        ),
        PlaceSuggestion(
          name: 'Petaling Jaya (Sunway Pyramid)',
          city: 'Petaling Jaya',
          state: 'Selangor',
          latitude: 3.0733,
          longitude: 101.6078,
          category: 'mall',
        ),
        PlaceSuggestion(
          name: 'Melaka (Ayer Keroh)',
          city: 'Ayer Keroh',
          state: 'Melaka',
          latitude: 2.2740,
          longitude: 102.2850,
          category: 'city',
        ),
      ];
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return defaultHubs;
    final results = <PlaceSuggestion>[];
    final seen = <String>{};
    void addUnique(PlaceSuggestion place) {
      final key = '${place.name.toLowerCase()}_${place.latitude.toStringAsFixed(3)}';
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(place);
      }
    }
    for (final p in MalaysianPlacesCatalog.allPlaces) {
      if (p.name.toLowerCase().contains(q) ||
          p.city.toLowerCase().contains(q) ||
          p.state.toLowerCase().contains(q)) {
        addUnique(p);
      }
    }
    try {
      final res = await _dio.get(
        '/api/v1/routing/places',
        queryParameters: {'q': query, 'limit': 8},
      );
      if (res.statusCode == 200 && res.data is List) {
        for (final item in res.data as List) {
          addUnique(PlaceSuggestion.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {}
    if (results.length >= 6) return results.take(8).toList();
    try {
      final photonDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
      final res = await photonDio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {
          'q': query,
          'lat': 3.1578,
          'lon': 101.7118,
          'limit': 6,
        },
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final features = res.data['features'] as List?;
        if (features != null) {
          for (final f in features) {
            final props = (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>?;
            final geom = f['geometry'] as Map<String, dynamic>?;
            final coords = geom?['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              final lng = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              if (lat >= 0.8 && lat <= 8.5 && lng >= 99.0 && lng <= 120.0) {
                final name = (props?['name'] ?? props?['street'] ?? query).toString();
                final city = (props?['city'] ?? props?['county'] ?? 'Malaysia').toString();
                final state = (props?['state'] ?? 'Malaysia').toString();
                addUnique(PlaceSuggestion(
                  name: name,
                  city: city,
                  state: state,
                  latitude: lat,
                  longitude: lng,
                  category: 'geocoded',
                ));
              }
            }
          }
        }
      }
    } catch (_) {}
    return results.take(8).toList();
  }
  Future<List<PlaceSuggestion>> fetchPlaces(String query) => searchPlaces(query);
  bool _isDirectionallyCompatible(
    String stationName,
    double stationLat,
    double originLat,
    double destLat,
  ) {
    final lower = stationName.toLowerCase();
    if (destLat - originLat > 0.15) {
      if (lower.contains('southbound') || lower.contains('arah selatan')) {
        return false;
      }
      if (stationLat < originLat - 0.05 || stationLat > destLat + 0.05) {
        return false;
      }
    } else if (originLat - destLat > 0.15) {
      if (lower.contains('northbound') || lower.contains('arah utara')) {
        return false;
      }
      if (stationLat > originLat + 0.05 || stationLat < destLat - 0.05) {
        return false;
      }
    }
    return true;
  }
  Future<RoutePlanResult> calculateRoutePlan({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required VehicleProfile vehicle,
    required int startingSocPercent,
    List<String> preferredStopStationIds = const [],
  }) async {
    final payload = {
      'origin_name': origin.name,
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'destination_name': destination.name,
      'destination_lat': destination.latitude,
      'destination_lng': destination.longitude,
      'vehicle_id': vehicle.id.isNotEmpty &&
              !vehicle.id.startsWith('local-') &&
              !vehicle.id.startsWith('garage-')
          ? vehicle.id
          : null,
      'starting_soc_percent': startingSocPercent,
      'battery_capacity_kwh': vehicle.batteryCapacityKwh,
      'efficiency_wh_per_km': vehicle.efficiencyWhPerKm,
      'max_dc_charge_kw': vehicle.maxDcChargeKw,
      'connector_type': vehicle.connectorType,
      'reserve_soc_percent': vehicle.reserveSocPercent,
      'corridor_radius_km': 25.0,
      'preferred_stop_station_ids': preferredStopStationIds,
    };
    try {
      final res = await _dio.post('/api/v1/routing/plan', data: payload);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return RoutePlanResult.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return _simulateOfflineRoute(
      origin: origin,
      destination: destination,
      vehicle: vehicle,
      startingSoc: startingSocPercent,
      preferredStopStationIds: preferredStopStationIds,
    );
  }
  Future<RoutePlanResult> _simulateOfflineRoute({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required VehicleProfile vehicle,
    required int startingSoc,
    List<String> preferredStopStationIds = const [],
  }) async {
    final straightDist = _haversineKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    double totalDist = double.parse((straightDist * 1.16).toStringAsFixed(1));
    int driveMins = max((totalDist / 85.0 * 60).round(), 5);
    List<LatLng>? roadPolyline = await _fetchDirectOsrmPolyline([
      LatLng(origin.latitude, origin.longitude),
      LatLng(destination.latitude, destination.longitude),
    ]);
    final totalEnergyKwh = double.parse(
        ((totalDist * vehicle.efficiencyWhPerKm) / 1000.0).toStringAsFixed(1));
    final usedSoc = (totalEnergyKwh / vehicle.batteryCapacityKwh) * 100.0;
    final projectedDestSoc = (startingSoc - usedSoc).round();
    final allStations = StationLocalCache.defaultMalaysianStations();
    final corridorStations = allStations
        .where((s) => _isDirectionallyCompatible(s.name, s.latitude, origin.latitude, destination.latitude))
        .toList();
    final stops = <ChargingStopRecommendation>[];
    int finalArrivalSoc = projectedDestSoc;
    String status = 'safe';
    String summary =
        'Destination reachable safely with $projectedDestSoc% battery remaining.';
    int totalChargeMins = 0;
    final polyline = roadPolyline ?? _synthesizeOfflinePolyline(origin, destination);
    if (projectedDestSoc < vehicle.reserveSocPercent) {
      status = 'critical_charging_required';
      summary =
          'Battery depletion risk: Route requires ${usedSoc.round()}% battery. Charging stop recommended.';
      ChargingStation chosenStation;
      if (preferredStopStationIds.isNotEmpty) {
        chosenStation = corridorStations.firstWhere(
          (s) => preferredStopStationIds.contains(s.id),
          orElse: () => corridorStations.firstWhere(
            (s) => s.name.contains('Tapah'),
            orElse: () => corridorStations.first,
          ),
        );
      } else {
        chosenStation = corridorStations.firstWhere(
          (s) => s.name.contains('Tapah'),
          orElse: () => corridorStations.first,
        );
      }
      final arrivalSoc = max((startingSoc - 35), 15);
      const departureSoc = 80;
      final addedKwh =
          ((departureSoc - arrivalSoc) / 100.0) * vehicle.batteryCapacityKwh;
      final effectiveKw = min(chosenStation.maxPowerKw, vehicle.maxDcChargeKw);
      final chargeMins =
          max((addedKwh / (effectiveKw * 0.85) * 60).round(), 18);
      final alternatives = corridorStations
          .where((s) => s.id != chosenStation.id && (s.city == 'Tapah' || s.city == 'Simpang Pulai' || s.city == 'Ipoh'))
          .take(4)
          .toList();
      final closestP = polyline.reduce((a, b) =>
          _haversineKm(a.latitude, a.longitude, chosenStation.latitude, chosenStation.longitude) <
                  _haversineKm(b.latitude, b.longitude, chosenStation.latitude, chosenStation.longitude)
              ? a
              : b);
      stops.add(
        ChargingStopRecommendation(
          station: chosenStation,
          distanceFromOriginKm: 152.0,
          detourDistanceKm: 0.5,
          arrivalSocPercent: arrivalSoc,
          departureSocPercent: departureSoc,
          energyAddedKwh: double.parse(addedKwh.toStringAsFixed(1)),
          estimatedChargeMinutes: chargeMins,
          estimatedCostMyr: double.parse((addedKwh * chosenStation.chargingCostMyr).toStringAsFixed(2)),
          corridorLat: closestP.latitude,
          corridorLng: closestP.longitude,
          nearbyAlternatives: alternatives,
        ),
      );
      totalChargeMins += chargeMins;
      finalArrivalSoc = max(
        (departureSoc -
                ((totalDist - 152.0) *
                    vehicle.efficiencyWhPerKm /
                    1000.0 /
                    vehicle.batteryCapacityKwh *
                    100.0))
            .round(),
        20,
      );
    } else if (projectedDestSoc < vehicle.reserveSocPercent + 10) {
      status = 'warning';
      summary =
          'Tight arrival battery ($projectedDestSoc% SoC). Approaching ${vehicle.reserveSocPercent}% safety reserve.';
    }
    return RoutePlanResult(
      originName: origin.name,
      destinationName: destination.name,
      totalDistanceKm: totalDist,
      estimatedDriveMinutes: driveMins,
      totalChargingMinutes: totalChargeMins,
      totalTripMinutes: driveMins + totalChargeMins,
      startingSocPercent: startingSoc,
      projectedDestinationSocWithoutCharging: projectedDestSoc,
      finalArrivalSocPercent: max(finalArrivalSoc, 0),
      totalEnergyKwh: totalEnergyKwh,
      rangeAnxietyStatus: status,
      statusSummary: summary,
      vehicleSummary: vehicle.displayName,
      polylinePoints: polyline,
      recommendedStops: stops,
      corridorStations: corridorStations,
    );
  }
  Future<List<LatLng>?> _fetchDirectOsrmPolyline(List<LatLng> waypoints) async {
    try {
      final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = 'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
      final res = await dio.get(url);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final routes = res.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geom = (routes[0] as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
          final rawCoords = geom?['coordinates'] as List?;
          if (rawCoords != null && rawCoords.isNotEmpty) {
            return rawCoords.map((c) {
              final list = c as List;
              return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
            }).toList();
          }
        }
      }
    } catch (_) {}
    return null;
  }
  List<LatLng> _synthesizeOfflinePolyline(PlaceSuggestion origin, PlaceSuggestion dest) {
    final isNorthbound = dest.latitude > origin.latitude && (dest.latitude - origin.latitude) > 1.2;
    final poly = <LatLng>[origin.latLng];
    if (isNorthbound) {
      poly.addAll(const [
        LatLng(3.3217, 101.5767), // Rawang
        LatLng(3.7250, 101.4800), // Tg Malim
        LatLng(4.1950, 101.2789), // Tapah RSA
        LatLng(4.5975, 101.0760), // Ipoh
        LatLng(4.8517, 100.7417), // Taiping
      ]);
    } else {
      for (int i = 1; i <= 6; i++) {
        final f = i / 7.0;
        poly.add(LatLng(
          origin.latitude + (dest.latitude - origin.latitude) * f,
          origin.longitude + (dest.longitude - origin.longitude) * f,
        ));
      }
    }
    poly.add(dest.latLng);
    return poly;
  }
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
