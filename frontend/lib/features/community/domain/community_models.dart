/// Domain models for Station Reviews, Check-Ins, and Survei Mikro Consensus.
class StationReview {
  final String id;
  final String stationId;
  final String authorName;
  final int rating;
  final String comment;
  final String workingStatus;
  final int waitTimeMinutes;
  final DateTime createdAt;

  const StationReview({
    required this.id,
    required this.stationId,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.workingStatus = 'working',
    this.waitTimeMinutes = 0,
    required this.createdAt,
  });

  factory StationReview.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return StationReview(
      id: json['id'] as String? ?? '',
      stationId: json['station_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'EV Driver',
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String? ?? '',
      workingStatus: json['working_status'] as String? ?? 'working',
      waitTimeMinutes: json['wait_time_minutes'] as int? ?? 0,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'author_name': authorName,
        'rating': rating,
        'comment': comment,
        'working_status': workingStatus,
        'wait_time_minutes': waitTimeMinutes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Aggregated community consensus metrics for an EV charging station.
class MicroSurveyConsensus {
  final String stationId;
  final int totalVotes;
  final int consensusThreshold;
  final String? consensusPlugStatus;
  final String? consensusParkingStatus;
  final String? consensusAccessDifficulty;
  final bool stationAutoUpdated;

  const MicroSurveyConsensus({
    required this.stationId,
    this.totalVotes = 0,
    this.consensusThreshold = 3,
    this.consensusPlugStatus,
    this.consensusParkingStatus,
    this.consensusAccessDifficulty,
    this.stationAutoUpdated = false,
  });

  bool get hasConsensus =>
      consensusPlugStatus != null ||
      consensusParkingStatus != null ||
      consensusAccessDifficulty != null;

  String get summaryBadgeText {
    final parts = <String>[];
    if (consensusPlugStatus != null) {
      parts.add(consensusPlugStatus == 'working'
          ? 'Plugs Working'
          : consensusPlugStatus == 'out_of_order'
              ? 'Plugs Broken'
              : 'Partial Working');
    }
    if (consensusParkingStatus != null) {
      parts.add(consensusParkingStatus == 'free' ? 'Free Entry' : 'Paid Parking');
    }
    if (consensusAccessDifficulty != null) {
      parts.add(consensusAccessDifficulty == 'hard_underground'
          ? 'Underground Maze'
          : 'Easy Access');
    }
    return parts.isEmpty ? 'Collecting Votes' : parts.join(' • ');
  }

  factory MicroSurveyConsensus.fromJson(Map<String, dynamic> json) {
    return MicroSurveyConsensus(
      stationId: json['station_id'] as String? ?? '',
      totalVotes: json['total_votes'] as int? ?? 0,
      consensusThreshold: json['consensus_threshold'] as int? ?? 3,
      consensusPlugStatus: json['consensus_plug_status'] as String?,
      consensusParkingStatus: json['consensus_parking_status'] as String?,
      consensusAccessDifficulty: json['consensus_access_difficulty'] as String?,
      stationAutoUpdated: json['station_auto_updated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'station_id': stationId,
        'total_votes': totalVotes,
        'consensus_threshold': consensusThreshold,
        'consensus_plug_status': consensusPlugStatus,
        'consensus_parking_status': consensusParkingStatus,
        'consensus_access_difficulty': consensusAccessDifficulty,
        'station_auto_updated': stationAutoUpdated,
      };
}
