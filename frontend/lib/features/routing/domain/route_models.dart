import 'package:latlong2/latlong.dart';
import '../../stations/domain/station_model.dart';

/// Formats minutes into human-friendly duration string (e.g. '45m', '2h', '8h 20m').
String formatDurationMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
}

/// Geocoded place or highway interchange waypoint.
class PlaceSuggestion {
  final String name, city, state, category;
  final double latitude, longitude;

  const PlaceSuggestion({
    required this.name, required this.city, required this.state,
    required this.latitude, required this.longitude, this.category = 'city',
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        name: json['name'] as String? ?? '', city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        category: json['category'] as String? ?? 'city',
      );

  Map<String, dynamic> toJson() => {
        'name': name, 'city': city, 'state': state,
        'latitude': latitude, 'longitude': longitude, 'category': category,
      };
}

/// Client request parameters for battery-aware highway corridor journey simulation.
class RoutePlanRequest {
  final PlaceSuggestion origin, destination;
  final String? vehicleId;
  final int startingSocPercent, reserveSocPercent;
  final double batteryCapacityKwh, efficiencyWhPerKm, maxDcChargeKw, corridorRadiusKm, targetArrivalSocPct;
  final String connectorType, stopStrategy, vehicleName;
  final List<String> preferredStopStationIds;
  final bool preferEasyAccess, isTeslaVehicle;

  const RoutePlanRequest({
    required this.origin, required this.destination, this.vehicleId,
    required this.startingSocPercent, required this.batteryCapacityKwh,
    required this.efficiencyWhPerKm, required this.maxDcChargeKw,
    required this.connectorType, required this.reserveSocPercent,
    this.corridorRadiusKm = 25.0, this.preferredStopStationIds = const [],
    this.stopStrategy = 'quickest', this.targetArrivalSocPct = 20.0, this.preferEasyAccess = true,
    this.vehicleName = '', this.isTeslaVehicle = false,
  });

  RoutePlanRequest copyWith({
    PlaceSuggestion? origin, PlaceSuggestion? destination, String? vehicleId,
    int? startingSocPercent, double? batteryCapacityKwh, double? efficiencyWhPerKm,
    double? maxDcChargeKw, String? connectorType, int? reserveSocPercent,
    double? corridorRadiusKm, List<String>? preferredStopStationIds,
    String? stopStrategy, double? targetArrivalSocPct, bool? preferEasyAccess,
    String? vehicleName, bool? isTeslaVehicle,
  }) => RoutePlanRequest(
        origin: origin ?? this.origin, destination: destination ?? this.destination,
        vehicleId: vehicleId ?? this.vehicleId,
        startingSocPercent: startingSocPercent ?? this.startingSocPercent,
        batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
        efficiencyWhPerKm: efficiencyWhPerKm ?? this.efficiencyWhPerKm,
        maxDcChargeKw: maxDcChargeKw ?? this.maxDcChargeKw,
        connectorType: connectorType ?? this.connectorType,
        reserveSocPercent: reserveSocPercent ?? this.reserveSocPercent,
        corridorRadiusKm: corridorRadiusKm ?? this.corridorRadiusKm,
        preferredStopStationIds: preferredStopStationIds ?? this.preferredStopStationIds,
        stopStrategy: stopStrategy ?? this.stopStrategy,
        targetArrivalSocPct: targetArrivalSocPct ?? this.targetArrivalSocPct,
        preferEasyAccess: preferEasyAccess ?? this.preferEasyAccess,
        vehicleName: vehicleName ?? this.vehicleName,
        isTeslaVehicle: isTeslaVehicle ?? this.isTeslaVehicle,
      );

  Map<String, dynamic> toJson() => {
        'origin_name': origin.name, 'origin_lat': origin.latitude, 'origin_lng': origin.longitude,
        'destination_name': destination.name, 'destination_lat': destination.latitude, 'destination_lng': destination.longitude,
        'vehicle_id': vehicleId, 'starting_soc_percent': startingSocPercent,
        'battery_capacity_kwh': batteryCapacityKwh, 'efficiency_wh_per_km': efficiencyWhPerKm,
        'max_dc_charge_kw': maxDcChargeKw, 'connector_type': connectorType,
        'reserve_soc_percent': reserveSocPercent, 'corridor_radius_km': corridorRadiusKm,
        'preferred_stop_station_ids': preferredStopStationIds,
        'stop_strategy': stopStrategy, 'target_arrival_soc_pct': targetArrivalSocPct,
        'prefer_easy_access': preferEasyAccess,
        'vehicle_name': vehicleName, 'is_tesla_vehicle': isTeslaVehicle,
      };
}

/// Recommended highway corridor charging pitstop.
class ChargingStopRecommendation {
  final ChargingStation station;
  final double distanceFromOriginKm, detourDistanceKm, energyAddedKwh, estimatedCostMyr;
  final int arrivalSocPercent, departureSocPercent, estimatedChargeMinutes;
  final double? corridorLat, corridorLng;
  final List<ChargingStation> nearbyAlternatives;

  const ChargingStopRecommendation({
    required this.station, required this.distanceFromOriginKm, required this.detourDistanceKm,
    required this.arrivalSocPercent, required this.departureSocPercent, required this.energyAddedKwh,
    required this.estimatedChargeMinutes, required this.estimatedCostMyr,
    this.corridorLat, this.corridorLng, this.nearbyAlternatives = const [],
  });

  ChargingStopRecommendation copyWith({
    ChargingStation? station, double? distanceFromOriginKm, double? detourDistanceKm,
    int? arrivalSocPercent, int? departureSocPercent, double? energyAddedKwh,
    int? estimatedChargeMinutes, double? estimatedCostMyr, double? corridorLat,
    double? corridorLng, List<ChargingStation>? nearbyAlternatives,
  }) => ChargingStopRecommendation(
        station: station ?? this.station, distanceFromOriginKm: distanceFromOriginKm ?? this.distanceFromOriginKm,
        detourDistanceKm: detourDistanceKm ?? this.detourDistanceKm, arrivalSocPercent: arrivalSocPercent ?? this.arrivalSocPercent,
        departureSocPercent: departureSocPercent ?? this.departureSocPercent, energyAddedKwh: energyAddedKwh ?? this.energyAddedKwh,
        estimatedChargeMinutes: estimatedChargeMinutes ?? this.estimatedChargeMinutes, estimatedCostMyr: estimatedCostMyr ?? this.estimatedCostMyr,
        corridorLat: corridorLat ?? this.corridorLat, corridorLng: corridorLng ?? this.corridorLng,
        nearbyAlternatives: nearbyAlternatives ?? this.nearbyAlternatives,
      );

  factory ChargingStopRecommendation.fromJson(Map<String, dynamic> json) {
    final rawAlts = json['nearby_alternatives'] as List<dynamic>? ?? [];
    return ChargingStopRecommendation(
      station: ChargingStation.fromJson(json['station'] as Map<String, dynamic>),
      distanceFromOriginKm: (json['distance_from_origin_km'] as num?)?.toDouble() ?? 0.0,
      detourDistanceKm: (json['detour_distance_km'] as num?)?.toDouble() ?? 0.0,
      arrivalSocPercent: json['arrival_soc_percent'] as int? ?? 15,
      departureSocPercent: json['departure_soc_percent'] as int? ?? 80,
      energyAddedKwh: (json['energy_added_kwh'] as num?)?.toDouble() ?? 0.0,
      estimatedChargeMinutes: json['estimated_charge_minutes'] as int? ?? 20,
      estimatedCostMyr: (json['estimated_cost_myr'] as num?)?.toDouble() ?? 0.0,
      corridorLat: (json['corridor_lat'] as num?)?.toDouble(),
      corridorLng: (json['corridor_lng'] as num?)?.toDouble(),
      nearbyAlternatives: rawAlts.map((a) => ChargingStation.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'station': station.toJson(), 'distance_from_origin_km': distanceFromOriginKm,
        'detour_distance_km': detourDistanceKm, 'arrival_soc_percent': arrivalSocPercent,
        'departure_soc_percent': departureSocPercent, 'energy_added_kwh': energyAddedKwh,
        'estimated_charge_minutes': estimatedChargeMinutes, 'estimated_cost_myr': estimatedCostMyr,
        'corridor_lat': corridorLat, 'corridor_lng': corridorLng,
        'nearby_alternatives': nearbyAlternatives.map((a) => a.toJson()).toList(),
      };
}

/// Complete simulated journey plan with battery telemetry and charging stop itinerary.
class RoutePlanResult {
  final String originName, destinationName, rangeAnxietyStatus, statusSummary, vehicleSummary;
  final double totalDistanceKm, totalEnergyKwh;
  final int estimatedDriveMinutes, totalChargingMinutes, totalTripMinutes, startingSocPercent;
  final int projectedDestinationSocWithoutCharging, finalArrivalSocPercent;
  final List<LatLng> polylinePoints;
  final List<ChargingStopRecommendation> recommendedStops;
  final List<ChargingStation> corridorStations;

  const RoutePlanResult({
    required this.originName, required this.destinationName, required this.totalDistanceKm,
    required this.estimatedDriveMinutes, required this.totalChargingMinutes, required this.totalTripMinutes,
    required this.startingSocPercent, required this.projectedDestinationSocWithoutCharging,
    required this.finalArrivalSocPercent, required this.totalEnergyKwh, required this.rangeAnxietyStatus,
    required this.statusSummary, required this.vehicleSummary, required this.polylinePoints,
    this.recommendedStops = const [], this.corridorStations = const [],
  });

  bool get isSafe => rangeAnxietyStatus == 'safe';
  bool get isWarning => rangeAnxietyStatus == 'warning';
  bool get isCritical => rangeAnxietyStatus == 'critical_charging_required';

  String get formattedDriveTime => formatDurationMinutes(estimatedDriveMinutes);
  String get formattedChargingTime => formatDurationMinutes(totalChargingMinutes);
  String get formattedTotalTripTime => formatDurationMinutes(totalTripMinutes);

  RoutePlanResult copyWith({
    String? originName, String? destinationName, double? totalDistanceKm,
    int? estimatedDriveMinutes, int? totalChargingMinutes, int? totalTripMinutes,
    int? startingSocPercent, int? projectedDestinationSocWithoutCharging,
    int? finalArrivalSocPercent, double? totalEnergyKwh, String? rangeAnxietyStatus,
    String? statusSummary, String? vehicleSummary, List<LatLng>? polylinePoints,
    List<ChargingStopRecommendation>? recommendedStops, List<ChargingStation>? corridorStations,
  }) => RoutePlanResult(
        originName: originName ?? this.originName, destinationName: destinationName ?? this.destinationName,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm, estimatedDriveMinutes: estimatedDriveMinutes ?? this.estimatedDriveMinutes,
        totalChargingMinutes: totalChargingMinutes ?? this.totalChargingMinutes, totalTripMinutes: totalTripMinutes ?? this.totalTripMinutes,
        startingSocPercent: startingSocPercent ?? this.startingSocPercent,
        projectedDestinationSocWithoutCharging: projectedDestinationSocWithoutCharging ?? this.projectedDestinationSocWithoutCharging,
        finalArrivalSocPercent: finalArrivalSocPercent ?? this.finalArrivalSocPercent, totalEnergyKwh: totalEnergyKwh ?? this.totalEnergyKwh,
        rangeAnxietyStatus: rangeAnxietyStatus ?? this.rangeAnxietyStatus, statusSummary: statusSummary ?? this.statusSummary,
        vehicleSummary: vehicleSummary ?? this.vehicleSummary, polylinePoints: polylinePoints ?? this.polylinePoints,
        recommendedStops: recommendedStops ?? this.recommendedStops, corridorStations: corridorStations ?? this.corridorStations,
      );

  factory RoutePlanResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['polyline_points'] as List<dynamic>? ?? [];
    final rawStops = json['recommended_stops'] as List<dynamic>? ?? [];
    final rawCorridor = json['corridor_stations'] as List<dynamic>? ?? [];

    return RoutePlanResult(
      originName: json['origin_name'] as String? ?? 'Origin',
      destinationName: json['destination_name'] as String? ?? 'Destination',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDriveMinutes: json['estimated_drive_minutes'] as int? ?? 0,
      totalChargingMinutes: json['total_charging_minutes'] as int? ?? 0,
      totalTripMinutes: json['total_trip_minutes'] as int? ?? 0,
      startingSocPercent: json['starting_soc_percent'] as int? ?? 80,
      projectedDestinationSocWithoutCharging: json['projected_destination_soc_without_charging'] as int? ?? 0,
      finalArrivalSocPercent: json['final_arrival_soc_percent'] as int? ?? 0,
      totalEnergyKwh: (json['total_energy_kwh'] as num?)?.toDouble() ?? 0.0,
      rangeAnxietyStatus: json['range_anxiety_status'] as String? ?? 'safe',
      statusSummary: json['status_summary'] as String? ?? '',
      vehicleSummary: json['vehicle_summary'] as String? ?? '',
      polylinePoints: rawPoints.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList(),
      recommendedStops: rawStops.map((s) => ChargingStopRecommendation.fromJson(s as Map<String, dynamic>)).toList(),
      corridorStations: rawCorridor.map((c) => ChargingStation.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'origin_name': originName, 'destination_name': destinationName,
        'total_distance_km': totalDistanceKm, 'estimated_drive_minutes': estimatedDriveMinutes,
        'total_charging_minutes': totalChargingMinutes, 'total_trip_minutes': totalTripMinutes,
        'starting_soc_percent': startingSocPercent,
        'projected_destination_soc_without_charging': projectedDestinationSocWithoutCharging,
        'final_arrival_soc_percent': finalArrivalSocPercent, 'total_energy_kwh': totalEnergyKwh,
        'range_anxiety_status': rangeAnxietyStatus, 'status_summary': statusSummary, 'vehicle_summary': vehicleSummary,
        'polyline_points': polylinePoints.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
        'recommended_stops': recommendedStops.map((s) => s.toJson()).toList(),
        'corridor_stations': corridorStations.map((c) => c.toJson()).toList(),
      };
}
