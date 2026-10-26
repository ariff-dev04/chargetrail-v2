/// Domain entity models representing EV Charging Stations, connectors, and filter parameters.
class PlugInfo {
  final String type;
  final double powerKw;
  final int count;

  const PlugInfo({
    required this.type,
    required this.powerKw,
    this.count = 1,
  });

  factory PlugInfo.fromJson(Map<String, dynamic> json) {
    return PlugInfo(
      type: json['type'] as String? ?? 'Unknown',
      powerKw: (json['power_kw'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'power_kw': powerKw,
        'count': count,
      };
}

/// Waypoint guidance helping drivers reach underground or hidden chargers.
class AccessStep {
  final int stepNumber;
  final String instruction;
  final String? photoUrl;

  const AccessStep({
    required this.stepNumber,
    required this.instruction,
    this.photoUrl,
  });

  factory AccessStep.fromJson(Map<String, dynamic> json) {
    return AccessStep(
      stepNumber: json['step_number'] as int? ?? 1,
      instruction: json['instruction'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'instruction': instruction,
        'photo_url': photoUrl,
      };
}

/// Core EV Charging Station entity with Malaysian access instructions and tariffs.
class ChargingStation {
  final String id;
  final String name;
  final String? operatorName;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final List<PlugInfo> plugTypes;
  final double maxPowerKw;
  final bool isAvailable;
  final bool is24Hours;
  final double chargingCostMyr;
  final double parkingFeeMyr;
  final String? parkingLevel;
  final String operationHours;
  final List<String> amenities;
  final List<AccessStep> howToAccess;
  final String? description;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String source;
  final double? distanceKm;

  const ChargingStation({
    required this.id,
    required this.name,
    this.operatorName,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.plugTypes = const [],
    required this.maxPowerKw,
    this.isAvailable = true,
    this.is24Hours = false,
    this.chargingCostMyr = 0.0,
    this.parkingFeeMyr = 0.0,
    this.parkingLevel,
    this.operationHours = '24 Hours',
    this.amenities = const [],
    this.howToAccess = const [],
    this.description,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = true,
    this.source = 'community',
    this.distanceKm,
  });

  factory ChargingStation.fromJson(Map<String, dynamic> json) {
    final rawPlugs = json['plug_types'] as List<dynamic>? ?? [];
    final plugs = rawPlugs
        .map((p) => PlugInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    final rawSteps = json['how_to_access'] as List<dynamic>? ?? [];
    final steps = rawSteps
        .map((s) => AccessStep.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawAmenities = json['amenities'] as List<dynamic>? ?? [];
    final amenitiesList = rawAmenities.map((e) => e.toString()).toList();

    return ChargingStation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      operatorName: json['operator_name'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      plugTypes: plugs,
      maxPowerKw: (json['max_power_kw'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['is_available'] as bool? ?? true,
      is24Hours: json['is_24_hours'] as bool? ?? false,
      chargingCostMyr: (json['charging_cost_myr'] as num?)?.toDouble() ?? 0.0,
      parkingFeeMyr: (json['parking_fee_myr'] as num?)?.toDouble() ?? 0.0,
      parkingLevel: json['parking_level'] as String?,
      operationHours: json['operation_hours'] as String? ?? '24 Hours',
      amenities: amenitiesList,
      howToAccess: steps,
      description: json['description'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? true,
      source: json['source'] as String? ?? 'community',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'operator_name': operatorName,
        'address': address,
        'city': city,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'plug_types': plugTypes.map((p) => p.toJson()).toList(),
        'max_power_kw': maxPowerKw,
        'is_available': isAvailable,
        'is_24_hours': is24Hours,
        'charging_cost_myr': chargingCostMyr,
        'parking_fee_myr': parkingFeeMyr,
        'parking_level': parkingLevel,
        'operation_hours': operationHours,
        'amenities': amenities,
        'how_to_access': howToAccess.map((s) => s.toJson()).toList(),
        'description': description,
        'rating': rating,
        'review_count': reviewCount,
        'is_verified': isVerified,
        'source': source,
        'distance_km': distanceKm,
      };
}

/// Immutable criteria container applied across stations in memory and local cache.
class StationFilter {
  final String? connectorType;
  final double? minKw;
  final String? amenity;
  final bool only24Hours;
  final String? searchQuery;

  const StationFilter({
    this.connectorType,
    this.minKw,
    this.amenity,
    this.only24Hours = false,
    this.searchQuery,
  });

  bool get hasActiveFilters =>
      connectorType != null ||
      minKw != null ||
      amenity != null ||
      only24Hours ||
      (searchQuery != null && searchQuery!.trim().isNotEmpty);

  StationFilter copyWith({
    String? connectorType,
    bool clearConnectorType = false,
    double? minKw,
    bool clearMinKw = false,
    String? amenity,
    bool clearAmenity = false,
    bool? only24Hours,
    String? searchQuery,
    bool clearSearchQuery = false,
  }) {
    return StationFilter(
      connectorType: clearConnectorType ? null : (connectorType ?? this.connectorType),
      minKw: clearMinKw ? null : (minKw ?? this.minKw),
      amenity: clearAmenity ? null : (amenity ?? this.amenity),
      only24Hours: only24Hours ?? this.only24Hours,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    );
  }

  /// Pure deterministic predicate testing if a given station satisfies current filter settings.
  bool matches(ChargingStation station) {
    // 1. Textual Search Filter
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
      final query = searchQuery!.trim().toLowerCase();
      final nameMatches = station.name.toLowerCase().contains(query);
      final operatorMatches =
          station.operatorName?.toLowerCase().contains(query) ?? false;
      final cityMatches = station.city.toLowerCase().contains(query);
      final addressMatches = station.address.toLowerCase().contains(query);

      if (!nameMatches && !operatorMatches && !cityMatches && !addressMatches) {
        return false;
      }
    }

    // 2. Connector Standard Filter
    if (connectorType != null && connectorType!.isNotEmpty) {
      final target = connectorType!.toLowerCase();
      final hasMatchingPlug = station.plugTypes.any(
        (plug) => plug.type.toLowerCase() == target,
      );
      if (!hasMatchingPlug) {
        return false;
      }
    }

    // 3. Peak Power Delivery Filter (kW)
    if (minKw != null && station.maxPowerKw < minKw!) {
      return false;
    }

    // 4. 24-Hour Access Filter
    if (only24Hours && !station.is24Hours) {
      return false;
    }

    // 5. Amenity Tag Filter
    if (amenity != null && amenity!.isNotEmpty) {
      final targetAmenity = amenity!.toLowerCase();
      final hasMatchingAmenity = station.amenities.any(
        (item) => item.toLowerCase().contains(targetAmenity),
      );
      if (!hasMatchingAmenity) {
        return false;
      }
    }

    return true;
  }
}
