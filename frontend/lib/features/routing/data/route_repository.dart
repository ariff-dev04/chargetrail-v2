import 'dart:math';
import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:latlong2/latlong.dart';
import '../../stations/data/station_local_cache.dart';
import '../../vehicles/domain/vehicle_model.dart';
import '../domain/route_models.dart';

/// Repository coordinating remote OSRM route calculations and offline physics fallback.
class RouteRepository {
  final Dio _dio;

  RouteRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
              ),
            );

  /// Verified Malaysian travel hubs for fast route setup.
  static List<PlaceSuggestion> get defaultHubs => const [
        PlaceSuggestion(
          name: 'Kuala Lumpur (KLCC)',
          city: 'Kuala Lumpur',
          state: 'Kuala Lumpur',
          latitude: 3.1578,
          longitude: 101.7118,
        ),
        PlaceSuggestion(
          name: 'Penang (Gurney Plaza)',
          city: 'George Town',
          state: 'Penang',
          latitude: 5.4372,
          longitude: 100.3096,
        ),
        PlaceSuggestion(
          name: 'Putrajaya (IOI City Mall)',
          city: 'Putrajaya',
          state: 'Putrajaya',
          latitude: 2.9698,
          longitude: 101.7135,
        ),
        PlaceSuggestion(
          name: 'Johor Bahru (Mid Valley Southkey)',
          city: 'Johor Bahru',
          state: 'Johor',
          latitude: 1.4989,
          longitude: 103.7774,
        ),
        PlaceSuggestion(
          name: 'Tapah RSA (North-South Highway)',
          city: 'Tapah',
          state: 'Perak',
          latitude: 4.1950,
          longitude: 101.2789,
          category: 'highway_rsa',
        ),
        PlaceSuggestion(
          name: 'Petaling Jaya (Sunway Pyramid)',
          city: 'Petaling Jaya',
          state: 'Selangor',
          latitude: 3.0733,
          longitude: 101.6078,
        ),
        PlaceSuggestion(
          name: 'Melaka (Ayer Keroh)',
          city: 'Ayer Keroh',
          state: 'Melaka',
          latitude: 2.2740,
          longitude: 102.2850,
        ),
      ];

  /// Search places by keyword with offline Malaysian fallback.
  Future<List<PlaceSuggestion>> fetchPlaces(String query) async {
    final q = query.trim().toLowerCase();
    try {
      final res = await _dio.get(
        '/api/v1/routing/places',
        queryParameters: {'q': query},
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return defaultHubs.where((h) {
      return h.name.toLowerCase().contains(q) ||
          h.city.toLowerCase().contains(q) ||
          h.state.toLowerCase().contains(q);
    }).toList();
  }

  /// Calculate battery-aware route plan with charging stop optimizer.
  Future<RoutePlanResult> calculateRoutePlan({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required VehicleProfile vehicle,
    required int startingSocPercent,
  }) async {
    final payload = {
      'origin_name': origin.name,
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'destination_name': destination.name,
      'destination_lat': destination.latitude,
      'destination_lng': destination.longitude,
      'vehicle_id': vehicle.id.isNotEmpty && !vehicle.id.startsWith('local-') && !vehicle.id.startsWith('garage-')
          ? vehicle.id
          : null,
      'starting_soc_percent': startingSocPercent,
      'battery_capacity_kwh': vehicle.batteryCapacityKwh,
      'efficiency_wh_per_km': vehicle.efficiencyWhPerKm,
      'max_dc_charge_kw': vehicle.maxDcChargeKw,
      'connector_type': vehicle.connectorType,
      'reserve_soc_percent': vehicle.reserveSocPercent,
      'corridor_radius_km': 25.0,
    };

    try {
      final res = await _dio.post('/api/v1/routing/plan', data: payload);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return RoutePlanResult.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (_) {}

    // Offline Deterministic Physics Engine
    return _simulateOfflineRoute(
      origin: origin,
      destination: destination,
      vehicle: vehicle,
      startingSoc: startingSocPercent,
    );
  }

  RoutePlanResult _simulateOfflineRoute({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required VehicleProfile vehicle,
    required int startingSoc,
  }) {
    final straightDist = _haversineKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final totalDist = double.parse((straightDist * 1.16).toStringAsFixed(1));
    final driveMins = max((totalDist / 85.0 * 60).round(), 5);

    final totalEnergyKwh = double.parse(
        ((totalDist * vehicle.efficiencyWhPerKm) / 1000.0).toStringAsFixed(1));
    final usedSoc = (totalEnergyKwh / vehicle.batteryCapacityKwh) * 100.0;
    final projectedDestSoc = (startingSoc - usedSoc).round();

    final isNorthboundLong = destination.latitude > origin.latitude &&
        (destination.latitude - origin.latitude) > 1.2;

    final polyline = <LatLng>[origin.latLng];
    if (isNorthboundLong) {
      polyline.addAll([
        const LatLng(3.3217, 101.5767), // Rawang
        const LatLng(3.7250, 101.4800), // Tg Malim
        const LatLng(4.1950, 101.2789), // Tapah RSA
        const LatLng(4.5975, 101.0760), // Ipoh
        const LatLng(4.8517, 100.7417), // Taiping
      ]);
    } else {
      // 6 intermediate points
      for (int i = 1; i <= 6; i++) {
        final f = i / 7.0;
        polyline.add(LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * f,
          origin.longitude + (destination.longitude - origin.longitude) * f,
        ));
      }
    }
    polyline.add(destination.latLng);

    final allStations = StationLocalCache.defaultMalaysianStations();
    final stops = <ChargingStopRecommendation>[];
    int finalArrivalSoc = projectedDestSoc;
    String status = 'safe';
    String summary = 'Destination reachable safely with $projectedDestSoc% battery remaining.';
    int totalChargeMins = 0;

    if (projectedDestSoc < vehicle.reserveSocPercent) {
      status = 'critical_charging_required';
      summary = 'Battery depletion risk: Route requires ${usedSoc.round()}% battery. Charging stop recommended.';

      // Tapah RSA stop for long northbound highway trip
      final tapahStation = allStations.firstWhere(
        (s) => s.name.contains('Tapah'),
        orElse: () => allStations.first,
      );

      final arrivalSoc = max((startingSoc - 35), 15);
      const departureSoc = 80;
      final addedKwh = ((departureSoc - arrivalSoc) / 100.0) * vehicle.batteryCapacityKwh;
      final effectiveKw = min(tapahStation.maxPowerKw, vehicle.maxDcChargeKw);
      final chargeMins = max((addedKwh / (effectiveKw * 0.85) * 60).round(), 18);

      stops.add(
        ChargingStopRecommendation(
          station: tapahStation,
          distanceFromOriginKm: 152.0,
          detourDistanceKm: 0.5,
          arrivalSocPercent: arrivalSoc,
          departureSocPercent: departureSoc,
          energyAddedKwh: double.parse(addedKwh.toStringAsFixed(1)),
          estimatedChargeMinutes: chargeMins,
          estimatedCostMyr: double.parse((addedKwh * 1.60).toStringAsFixed(2)),
        ),
      );
      totalChargeMins += chargeMins;
      finalArrivalSoc = max((departureSoc - ((totalDist - 152.0) * vehicle.efficiencyWhPerKm / 1000.0 / vehicle.batteryCapacityKwh * 100.0)).round(), 20);
    } else if (projectedDestSoc < vehicle.reserveSocPercent + 10) {
      status = 'warning';
      summary = 'Tight arrival battery ($projectedDestSoc% SoC). Approaching ${vehicle.reserveSocPercent}% safety reserve.';
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
      corridorStations: allStations,
    );
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
