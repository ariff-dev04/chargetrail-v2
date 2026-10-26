import 'package:latlong2/latlong.dart';
import '../../stations/domain/station_model.dart';

/// Geocoded place or highway interchange waypoint.
class PlaceSuggestion {
  final String name;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String category;

  const PlaceSuggestion({
    required this.name,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.category = 'city',
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'city',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
      };
}

/// Recommended highway corridor charging pitstop.
class ChargingStopRecommendation {
  final ChargingStation station;
  final double distanceFromOriginKm;
  final double detourDistanceKm;
  final int arrivalSocPercent;
  final int departureSocPercent;
  final double energyAddedKwh;
  final int estimatedChargeMinutes;
  final double estimatedCostMyr;

  const ChargingStopRecommendation({
    required this.station,
    required this.distanceFromOriginKm,
    required this.detourDistanceKm,
    required this.arrivalSocPercent,
    required this.departureSocPercent,
    required this.energyAddedKwh,
    required this.estimatedChargeMinutes,
    required this.estimatedCostMyr,
  });

  factory ChargingStopRecommendation.fromJson(Map<String, dynamic> json) {
    return ChargingStopRecommendation(
      station: ChargingStation.fromJson(json['station'] as Map<String, dynamic>),
      distanceFromOriginKm:
          (json['distance_from_origin_km'] as num?)?.toDouble() ?? 0.0,
      detourDistanceKm:
          (json['detour_distance_km'] as num?)?.toDouble() ?? 0.0,
      arrivalSocPercent: json['arrival_soc_percent'] as int? ?? 15,
      departureSocPercent: json['departure_soc_percent'] as int? ?? 80,
      energyAddedKwh: (json['energy_added_kwh'] as num?)?.toDouble() ?? 0.0,
      estimatedChargeMinutes:
          json['estimated_charge_minutes'] as int? ?? 20,
      estimatedCostMyr:
          (json['estimated_cost_myr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'station': station.toJson(),
        'distance_from_origin_km': distanceFromOriginKm,
        'detour_distance_km': detourDistanceKm,
        'arrival_soc_percent': arrivalSocPercent,
        'departure_soc_percent': departureSocPercent,
        'energy_added_kwh': energyAddedKwh,
        'estimated_charge_minutes': estimatedChargeMinutes,
        'estimated_cost_myr': estimatedCostMyr,
      };
}

/// Complete simulated journey plan with battery telemetry and charging stop itinerary.
class RoutePlanResult {
  final String originName;
  final String destinationName;
  final double totalDistanceKm;
  final int estimatedDriveMinutes;
  final int totalChargingMinutes;
  final int totalTripMinutes;
  final int startingSocPercent;
  final int projectedDestinationSocWithoutCharging;
  final int finalArrivalSocPercent;
  final double totalEnergyKwh;
  final String rangeAnxietyStatus; // safe, warning, critical_charging_required
  final String statusSummary;
  final String vehicleSummary;
  final List<LatLng> polylinePoints;
  final List<ChargingStopRecommendation> recommendedStops;
  final List<ChargingStation> corridorStations;

  const RoutePlanResult({
    required this.originName,
    required this.destinationName,
    required this.totalDistanceKm,
    required this.estimatedDriveMinutes,
    required this.totalChargingMinutes,
    required this.totalTripMinutes,
    required this.startingSocPercent,
    required this.projectedDestinationSocWithoutCharging,
    required this.finalArrivalSocPercent,
    required this.totalEnergyKwh,
    required this.rangeAnxietyStatus,
    required this.statusSummary,
    required this.vehicleSummary,
    required this.polylinePoints,
    this.recommendedStops = const [],
    this.corridorStations = const [],
  });

  bool get isSafe => rangeAnxietyStatus == 'safe';
  bool get isWarning => rangeAnxietyStatus == 'warning';
  bool get isCritical => rangeAnxietyStatus == 'critical_charging_required';

  factory RoutePlanResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['polyline_points'] as List<dynamic>? ?? [];
    final points = rawPoints.map((p) {
      final lat = (p['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (p['longitude'] as num?)?.toDouble() ?? 0.0;
      return LatLng(lat, lng);
    }).toList();

    final rawStops = json['recommended_stops'] as List<dynamic>? ?? [];
    final stops = rawStops
        .map((s) => ChargingStopRecommendation.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawCorridor = json['corridor_stations'] as List<dynamic>? ?? [];
    final corridor = rawCorridor
        .map((c) => ChargingStation.fromJson(c as Map<String, dynamic>))
        .toList();

    return RoutePlanResult(
      originName: json['origin_name'] as String? ?? 'Origin',
      destinationName: json['destination_name'] as String? ?? 'Destination',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDriveMinutes: json['estimated_drive_minutes'] as int? ?? 0,
      totalChargingMinutes: json['total_charging_minutes'] as int? ?? 0,
      totalTripMinutes: json['total_trip_minutes'] as int? ?? 0,
      startingSocPercent: json['starting_soc_percent'] as int? ?? 80,
      projectedDestinationSocWithoutCharging:
          json['projected_destination_soc_without_charging'] as int? ?? 0,
      finalArrivalSocPercent: json['final_arrival_soc_percent'] as int? ?? 0,
      totalEnergyKwh: (json['total_energy_kwh'] as num?)?.toDouble() ?? 0.0,
      rangeAnxietyStatus:
          json['range_anxiety_status'] as String? ?? 'safe',
      statusSummary: json['status_summary'] as String? ?? '',
      vehicleSummary: json['vehicle_summary'] as String? ?? '',
      polylinePoints: points,
      recommendedStops: stops,
      corridorStations: corridor,
    );
  }

  Map<String, dynamic> toJson() => {
        'origin_name': originName,
        'destination_name': destinationName,
        'total_distance_km': totalDistanceKm,
        'estimated_drive_minutes': estimatedDriveMinutes,
        'total_charging_minutes': totalChargingMinutes,
        'total_trip_minutes': totalTripMinutes,
        'starting_soc_percent': startingSocPercent,
        'projected_destination_soc_without_charging':
            projectedDestinationSocWithoutCharging,
        'final_arrival_soc_percent': finalArrivalSocPercent,
        'total_energy_kwh': totalEnergyKwh,
        'range_anxiety_status': rangeAnxietyStatus,
        'status_summary': statusSummary,
        'vehicle_summary': vehicleSummary,
        'polyline_points': polylinePoints
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
        'recommended_stops': recommendedStops.map((s) => s.toJson()).toList(),
        'corridor_stations': corridorStations.map((c) => c.toJson()).toList(),
      };
}
