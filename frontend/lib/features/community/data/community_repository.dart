import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../stations/domain/station_model.dart';
import '../domain/community_models.dart';

/// Repository coordinating community station submissions, reviews, consensus telemetry, and edit proposals.
class CommunityRepository {
  static const String _pendingStationsKey = 'chargetrail_pending_stations_v1';
  static const String _reviewsPrefix = 'chargetrail_reviews_v1_';
  static const String _surveysPrefix = 'chargetrail_surveys_v1_';
  static const String _editsPrefix = 'chargetrail_edits_v1_';

  final Dio _dio;
  final SharedPreferences? prefs;

  CommunityRepository({Dio? dio, this.prefs, String? baseUrl})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)));

  /// Submit a newly discovered or hidden community EV charger.
  Future<ChargingStation> submitStation(ChargingStation station) async {
    try {
      final response = await _dio.post(
        '/api/v1/community/stations',
        data: station.toJson(),
      );
      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        return ChargingStation.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    // Offline / Demo Fallback
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_pendingStationsKey);
    final list = raw != null
        ? (jsonDecode(raw) as List)
            .map((e) => ChargingStation.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ChargingStation>[];

    final pendingStation = ChargingStation(
      id: 'community-${DateTime.now().millisecondsSinceEpoch}',
      name: station.name, operatorName: station.operatorName, address: station.address,
      city: station.city, state: station.state, latitude: station.latitude, longitude: station.longitude,
      plugTypes: station.plugTypes, maxPowerKw: station.maxPowerKw, isAvailable: station.isAvailable,
      parkingLevel: station.parkingLevel, howToAccess: station.howToAccess, source: 'community', isVerified: false,
    );
    list.add(pendingStation);
    await p.setString(_pendingStationsKey, jsonEncode(list.map((s) => s.toJson()).toList()));
    return pendingStation;
  }

  /// Retrieve list of unverified community submissions awaiting moderation.
  Future<List<ChargingStation>> fetchPendingStations() async {
    try {
      final response = await _dio.get('/api/v1/community/stations/pending');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => ChargingStation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_pendingStationsKey);
    if (raw != null && raw.isNotEmpty) {
      return (jsonDecode(raw) as List)
          .map((e) => ChargingStation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Approve or reject a pending station submission.
  Future<ChargingStation?> moderateStation(String stationId, bool approve) async {
    try {
      final response = await _dio.patch(
        '/api/v1/community/stations/$stationId/moderate',
        data: {'approve': approve},
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ChargingStation.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_pendingStationsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => ChargingStation.fromJson(e as Map<String, dynamic>))
          .toList();
      final index = list.indexWhere((s) => s.id == stationId);
      if (index != -1) {
        final target = list.removeAt(index);
        await p.setString(_pendingStationsKey, jsonEncode(list.map((s) => s.toJson()).toList()));
        if (approve) {
          return ChargingStation(
            id: target.id, name: target.name, operatorName: target.operatorName, address: target.address,
            city: target.city, state: target.state, latitude: target.latitude, longitude: target.longitude,
            plugTypes: target.plugTypes, maxPowerKw: target.maxPowerKw, parkingLevel: target.parkingLevel,
            howToAccess: target.howToAccess, source: 'community', isVerified: true,
          );
        }
      }
    }
    return null;
  }

  /// Post a driver review or check-in.
  Future<StationReview> postReview({
    required String stationId,
    required int rating,
    required String comment,
    required String authorName,
    String workingStatus = 'working',
    int waitTimeMinutes = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/community/stations/$stationId/reviews',
        data: {
          'rating': rating,
          'comment': comment,
          'author_name': authorName,
          'working_status': workingStatus,
          'wait_time_minutes': waitTimeMinutes,
        },
      );
      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        return StationReview.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    final review = StationReview(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      stationId: stationId,
      authorName: authorName,
      rating: rating,
      comment: comment,
      workingStatus: workingStatus,
      waitTimeMinutes: waitTimeMinutes,
      createdAt: DateTime.now(),
    );

    final p = prefs ?? await SharedPreferences.getInstance();
    final key = '$_reviewsPrefix$stationId';
    final existing = p.getString(key);
    final list = existing != null
        ? (jsonDecode(existing) as List).map((e) => StationReview.fromJson(e as Map<String, dynamic>)).toList()
        : <StationReview>[];
    list.insert(0, review);
    await p.setString(key, jsonEncode(list.map((r) => r.toJson()).toList()));
    return review;
  }

  /// Fetch all reviews for a station.
  Future<List<StationReview>> fetchReviews(String stationId) async {
    try {
      final response = await _dio.get('/api/v1/community/stations/$stationId/reviews');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => StationReview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('$_reviewsPrefix$stationId');
    if (raw != null) {
      return (jsonDecode(raw) as List)
          .map((e) => StationReview.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [
      StationReview(
        id: 'default-rev-1',
        stationId: stationId,
        authorName: 'Ahmad Faiz (Verified Driver)',
        rating: 5,
        comment: 'Charged successfully at high speed. Followed Pillar markers easily.',
        workingStatus: 'working',
        waitTimeMinutes: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  /// Submit 1-tap Survei Mikro vote and retrieve updated consensus telemetry.
  Future<MicroSurveyConsensus> voteMicroSurvey({
    required String stationId,
    required String plugStatus,
    required String parkingStatus,
    required String accessDifficulty,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/community/stations/$stationId/micro-survey',
        data: {
          'plug_working_status': plugStatus,
          'parking_fee_status': parkingStatus,
          'access_difficulty': accessDifficulty,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return MicroSurveyConsensus.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final key = '$_surveysPrefix$stationId';
    final existing = p.getString(key);
    final votes = existing != null ? (jsonDecode(existing) as List) : [];
    votes.add({
      'plug': plugStatus,
      'parking': parkingStatus,
      'access': accessDifficulty,
    });
    await p.setString(key, jsonEncode(votes));

    final count = votes.length;
    final plugCount = votes.where((v) => v['plug'] == plugStatus).length;
    final parkingCount = votes.where((v) => v['parking'] == parkingStatus).length;
    final accessCount = votes.where((v) => v['access'] == accessDifficulty).length;

    return MicroSurveyConsensus(
      stationId: stationId,
      totalVotes: count,
      consensusThreshold: 3,
      consensusPlugStatus: plugCount >= 3 ? plugStatus : null,
      consensusParkingStatus: parkingCount >= 3 ? parkingStatus : null,
      consensusAccessDifficulty: accessCount >= 3 ? accessDifficulty : null,
      stationAutoUpdated: plugCount >= 3 || parkingCount >= 3,
    );
  }

  /// Fetch current consensus telemetry for a station.
  Future<MicroSurveyConsensus> fetchConsensus(String stationId) async {
    try {
      final response = await _dio.get('/api/v1/community/stations/$stationId/micro-survey');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return MicroSurveyConsensus.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('$_surveysPrefix$stationId');
    if (raw != null) {
      final votes = jsonDecode(raw) as List;
      return MicroSurveyConsensus(
        stationId: stationId,
        totalVotes: votes.length,
        consensusThreshold: 3,
        consensusPlugStatus: votes.length >= 3 ? 'working' : null,
        consensusParkingStatus: votes.length >= 3 ? 'paid' : null,
      );
    }
    return MicroSurveyConsensus(stationId: stationId, totalVotes: 0);
  }

  /// Propose field updates to an existing charging station (KF06).
  Future<Map<String, dynamic>> suggestStationEdit(
    String stationId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/community/stations/$stationId/suggest-edit',
        data: payload,
      );
      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final key = '$_editsPrefix$stationId';
    final existing = p.getString(key);
    final list = existing != null ? (jsonDecode(existing) as List) : [];
    final editData = {
      'id': 'edit-${DateTime.now().millisecondsSinceEpoch}',
      'station_id': stationId,
      'author_name': 'EV Driver',
      'parking_level': payload['parking_level'],
      'description': payload['description'],
      'price_per_kwh': payload['price_per_kwh'],
      'max_power_kw': payload['max_power_kw'],
      'amenities': payload['amenities'],
      'is_operational': payload['is_operational'],
      'confirm_votes': 0,
      'reject_votes': 0,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    list.insert(0, editData);
    await p.setString(key, jsonEncode(list));
    return editData;
  }

  /// Retrieve all pending edit proposals for a station (KF09).
  Future<List<Map<String, dynamic>>> fetchPendingStationEdits(String stationId) async {
    try {
      final response = await _dio.get('/api/v1/community/stations/$stationId/pending-edits');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('$_editsPrefix$stationId');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return list.where((e) => e['status'] == 'pending').toList();
    }
    return [];
  }

  /// Cast confirm/reject vote or fast-track approve a station edit proposal (KF09).
  Future<Map<String, dynamic>> voteOnStationEdit(
    String editId, {
    required String vote,
    bool fastTrackApprove = false,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/community/edits/$editId/vote',
        data: {
          'vote': vote,
          'fast_track_approve': fastTrackApprove,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}

    final p = prefs ?? await SharedPreferences.getInstance();
    final keys = p.getKeys().where((k) => k.startsWith(_editsPrefix));
    for (final k in keys) {
      final raw = p.getString(k);
      if (raw == null) continue;
      final list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final idx = list.indexWhere((e) => e['id'] == editId);
      if (idx != -1) {
        final item = Map<String, dynamic>.from(list[idx]);
        if (fastTrackApprove) {
          item['confirm_votes'] = (item['confirm_votes'] as int? ?? 0) + 1;
          item['status'] = 'approved';
        } else if (vote == 'confirm') {
          final c = (item['confirm_votes'] as int? ?? 0) + 1;
          item['confirm_votes'] = c;
          if (c >= 3) item['status'] = 'approved';
        } else {
          final r = (item['reject_votes'] as int? ?? 0) + 1;
          item['reject_votes'] = r;
          if (r >= 3) item['status'] = 'rejected';
        }
        item['updated_at'] = DateTime.now().toIso8601String();
        list[idx] = item;
        await p.setString(k, jsonEncode(list));
        return item;
      }
    }
    return {'id': editId, 'status': fastTrackApprove ? 'approved' : 'pending'};
  }
}
