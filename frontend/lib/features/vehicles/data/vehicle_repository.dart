import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/vehicle_model.dart';

/// Repository managing EV garage profiles, battery specs, and Malaysian preset models.
class VehicleRepository {
  static const String _garageStorageKey = 'chargetrail_garage_vehicles_v1';

  final Dio _dio;
  final SharedPreferences? prefs;

  VehicleRepository({
    Dio? dio,
    this.prefs,
    String? baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
              ),
            );

  /// Verified Malaysian factory presets available for 1-tap addition.
  static List<VehicleProfile> get defaultPresets => const [
        VehicleProfile(
          id: 'preset-proton-emas-7',
          brand: 'Proton',
          modelName: 'e.MAS 7 Prime',
          batteryCapacityKwh: 60.22,
          usableRangeKm: 410.0,
          efficiencyWhPerKm: 147.0,
          maxDcChargeKw: 100.0,
          connectorType: 'CCS2',
        ),
        VehicleProfile(
          id: 'preset-byd-atto-3',
          brand: 'BYD',
          modelName: 'Atto 3 Extended Range',
          batteryCapacityKwh: 60.48,
          usableRangeKm: 420.0,
          efficiencyWhPerKm: 144.0,
          maxDcChargeKw: 88.0,
          connectorType: 'CCS2',
        ),
        VehicleProfile(
          id: 'preset-tesla-model-3',
          brand: 'Tesla',
          modelName: 'Model 3 Long Range AWD',
          batteryCapacityKwh: 75.0,
          usableRangeKm: 629.0,
          efficiencyWhPerKm: 125.0,
          maxDcChargeKw: 250.0,
          connectorType: 'CCS2',
        ),
        VehicleProfile(
          id: 'preset-byd-dolphin',
          brand: 'BYD',
          modelName: 'Dolphin Dynamic / Premium',
          batteryCapacityKwh: 60.48,
          usableRangeKm: 427.0,
          efficiencyWhPerKm: 142.0,
          maxDcChargeKw: 88.0,
          connectorType: 'CCS2',
        ),
        VehicleProfile(
          id: 'preset-hyundai-ioniq-5',
          brand: 'Hyundai',
          modelName: 'IONIQ 5 Max AWD',
          batteryCapacityKwh: 72.6,
          usableRangeKm: 430.0,
          efficiencyWhPerKm: 169.0,
          maxDcChargeKw: 233.0,
          connectorType: 'CCS2',
        ),
        VehicleProfile(
          id: 'preset-nissan-leaf',
          brand: 'Nissan',
          modelName: 'Leaf e+ (CHAdeMO Legacy)',
          batteryCapacityKwh: 59.0,
          usableRangeKm: 385.0,
          efficiencyWhPerKm: 153.0,
          maxDcChargeKw: 50.0,
          connectorType: 'CHAdeMO',
        ),
      ];

  /// Retrieve garage vehicles from backend or local offline storage.
  Future<List<VehicleProfile>> fetchVehicles() async {
    try {
      final response = await _dio.get('/api/v1/vehicles');
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((e) => VehicleProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          await _saveLocal(list);
          return list;
        }
      }
    } catch (_) {}

    // Offline Fallback
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_garageStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List)
          .map((e) => VehicleProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }

    // Default Malaysian Garage Baseline
    final baseline = [
      defaultPresets[0].copyWith(id: 'garage-v1', isPrimary: true, nickname: 'My Daily e.MAS 7'),
      defaultPresets[1].copyWith(id: 'garage-v2', isPrimary: false, nickname: 'Family Atto 3'),
    ];
    await _saveLocal(baseline);
    return baseline;
  }

  /// Add a new EV to user's garage.
  Future<VehicleProfile> addVehicle(VehicleProfile vehicle) async {
    try {
      final response = await _dio.post(
        '/api/v1/vehicles',
        data: vehicle.toJson(),
      );
      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        final created = VehicleProfile.fromJson(response.data as Map<String, dynamic>);
        final current = await fetchVehicles();
        current.insert(0, created);
        await _saveLocal(current);
        return created;
      }
    } catch (_) {}

    // Offline Fallback
    final current = await fetchVehicles();
    final newId = 'local-veh-${DateTime.now().millisecondsSinceEpoch}';
    final created = vehicle.copyWith(id: newId);

    final updated = current.map((v) => vehicle.isPrimary ? v.copyWith(isPrimary: false) : v).toList();
    updated.insert(0, created);
    await _saveLocal(updated);
    return created;
  }

  /// Update specifications on an existing EV profile.
  Future<VehicleProfile> updateVehicle(VehicleProfile vehicle) async {
    try {
      final response = await _dio.patch(
        '/api/v1/vehicles/${vehicle.id}',
        data: vehicle.toJson(),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final updated = VehicleProfile.fromJson(response.data as Map<String, dynamic>);
        await _updateLocal(updated);
        return updated;
      }
    } catch (_) {}

    // Offline update
    await _updateLocal(vehicle);
    return vehicle;
  }

  /// Set selected vehicle as the primary active EV.
  Future<void> setPrimary(String vehicleId) async {
    try {
      await _dio.post('/api/v1/vehicles/$vehicleId/select');
    } catch (_) {}

    final current = await fetchVehicles();
    final updated = current.map((v) => v.copyWith(isPrimary: v.id == vehicleId)).toList();
    await _saveLocal(updated);
  }

  /// Delete EV from user's garage.
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _dio.delete('/api/v1/vehicles/$vehicleId');
    } catch (_) {}

    final current = await fetchVehicles();
    final updated = current.where((v) => v.id != vehicleId).toList();
    if (updated.isNotEmpty && !updated.any((v) => v.isPrimary)) {
      updated[0] = updated[0].copyWith(isPrimary: true);
    }
    await _saveLocal(updated);
  }

  Future<void> _saveLocal(List<VehicleProfile> list) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(_garageStorageKey, jsonEncode(list.map((v) => v.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _updateLocal(VehicleProfile vehicle) async {
    final current = await fetchVehicles();
    final index = current.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      current[index] = vehicle;
      await _saveLocal(current);
    }
  }
}
