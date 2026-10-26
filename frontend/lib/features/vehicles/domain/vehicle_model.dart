import 'dart:math';

/// Immutable domain model representing an Electric Vehicle profile and battery telemetry.
class VehicleProfile {
  final String id;
  final String? userId;
  final String brand;
  final String modelName;
  final String? nickname;
  final double batteryCapacityKwh;
  final double usableRangeKm;
  final double efficiencyWhPerKm;
  final double maxDcChargeKw;
  final String connectorType;
  final int reserveSocPercent;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VehicleProfile({
    required this.id,
    this.userId,
    required this.brand,
    required this.modelName,
    this.nickname,
    required this.batteryCapacityKwh,
    required this.usableRangeKm,
    required this.efficiencyWhPerKm,
    required this.maxDcChargeKw,
    this.connectorType = 'CCS2',
    this.reserveSocPercent = 15,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Display name combining nickname or brand + model trim.
  String get displayName =>
      nickname != null && nickname!.trim().isNotEmpty
          ? nickname!
          : '$brand $modelName';

  /// Total theoretical driving range at a specific state of charge percentage.
  double rangeAtSocKm(int currentSocPercent) {
    final socFactor = currentSocPercent.clamp(0, 100) / 100.0;
    return double.parse((usableRangeKm * socFactor).toStringAsFixed(1));
  }

  /// Usable range buffer remaining before reaching the driver's safety reserve buffer.
  double safeUsableRangeAtSocKm(int currentSocPercent) {
    final effectiveSoc =
        (currentSocPercent.clamp(0, 100) - reserveSocPercent).clamp(0, 100);
    return double.parse(
        (usableRangeKm * (effectiveSoc / 100.0)).toStringAsFixed(1));
  }

  /// Estimate 20% to 80% charging duration in minutes given the station's peak power.
  int estimateChargeMinutes20To80(double stationMaxKw) {
    if (stationMaxKw <= 0) return 60;
    // Energy required from 20% to 80% is 60% of gross capacity
    final energyKwh = 0.60 * batteryCapacityKwh;
    // Effective power delivery throttled by either station or vehicle OBC limit
    final effectiveKw = min(stationMaxKw, maxDcChargeKw);
    // Real-world charging taper curve factor (~85% average speed efficiency)
    final hours = energyKwh / (effectiveKw * 0.85);
    final minutes = (hours * 60).round();
    return minutes.clamp(12, 120);
  }

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    return VehicleProfile(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      brand: json['brand'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      nickname: json['nickname'] as String?,
      batteryCapacityKwh:
          (json['battery_capacity_kwh'] as num?)?.toDouble() ?? 60.0,
      usableRangeKm: (json['usable_range_km'] as num?)?.toDouble() ?? 400.0,
      efficiencyWhPerKm:
          (json['efficiency_wh_per_km'] as num?)?.toDouble() ?? 150.0,
      maxDcChargeKw:
          (json['max_dc_charge_kw'] as num?)?.toDouble() ?? 100.0,
      connectorType: json['connector_type'] as String? ?? 'CCS2',
      reserveSocPercent: json['reserve_soc_percent'] as int? ?? 15,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'brand': brand,
        'model_name': modelName,
        'nickname': nickname,
        'battery_capacity_kwh': batteryCapacityKwh,
        'usable_range_km': usableRangeKm,
        'efficiency_wh_per_km': efficiencyWhPerKm,
        'max_dc_charge_kw': maxDcChargeKw,
        'connector_type': connectorType,
        'reserve_soc_percent': reserveSocPercent,
        'is_primary': isPrimary,
        'effective_safe_range_km':
            safeUsableRangeAtSocKm(100),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  VehicleProfile copyWith({
    String? id,
    String? userId,
    String? brand,
    String? modelName,
    String? nickname,
    bool clearNickname = false,
    double? batteryCapacityKwh,
    double? usableRangeKm,
    double? efficiencyWhPerKm,
    double? maxDcChargeKw,
    String? connectorType,
    int? reserveSocPercent,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      brand: brand ?? this.brand,
      modelName: modelName ?? this.modelName,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
      usableRangeKm: usableRangeKm ?? this.usableRangeKm,
      efficiencyWhPerKm: efficiencyWhPerKm ?? this.efficiencyWhPerKm,
      maxDcChargeKw: maxDcChargeKw ?? this.maxDcChargeKw,
      connectorType: connectorType ?? this.connectorType,
      reserveSocPercent: reserveSocPercent ?? this.reserveSocPercent,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
