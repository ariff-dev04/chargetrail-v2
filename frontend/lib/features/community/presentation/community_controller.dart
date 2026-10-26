import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stations/domain/station_model.dart';
import '../../stations/presentation/station_controller.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// State representation for station reviews, consensus metrics, and moderation queue.
class CommunityState {
  final Map<String, List<StationReview>> reviewsByStation;
  final Map<String, MicroSurveyConsensus> consensusByStation;
  final List<ChargingStation> pendingStations;
  final bool isLoading;
  final String? message;

  const CommunityState({
    this.reviewsByStation = const {},
    this.consensusByStation = const {},
    this.pendingStations = const [],
    this.isLoading = false,
    this.message,
  });

  CommunityState copyWith({
    Map<String, List<StationReview>>? reviewsByStation,
    Map<String, MicroSurveyConsensus>? consensusByStation,
    List<ChargingStation>? pendingStations,
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) {
    return CommunityState(
      reviewsByStation: reviewsByStation ?? this.reviewsByStation,
      consensusByStation: consensusByStation ?? this.consensusByStation,
      pendingStations: pendingStations ?? this.pendingStations,
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Dependency provider for CommunityRepository.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

/// Riverpod controller managing community reviews, consensus polling, and submissions.
class CommunityNotifier extends Notifier<CommunityState> {
  @override
  CommunityState build() {
    return const CommunityState();
  }

  /// Load reviews and consensus telemetry for a station.
  Future<void> loadStationCommunityData(String stationId) async {
    final repo = ref.read(communityRepositoryProvider);
    final reviews = await repo.fetchReviews(stationId);
    final consensus = await repo.fetchConsensus(stationId);

    final updatedReviews = Map<String, List<StationReview>>.from(state.reviewsByStation);
    updatedReviews[stationId] = reviews;

    final updatedConsensus = Map<String, MicroSurveyConsensus>.from(state.consensusByStation);
    updatedConsensus[stationId] = consensus;

    state = state.copyWith(
      reviewsByStation: updatedReviews,
      consensusByStation: updatedConsensus,
    );
  }

  /// Submit driver check-in review and refresh station review list.
  Future<bool> postReview({
    required String stationId,
    required int rating,
    required String comment,
    required String authorName,
    String workingStatus = 'working',
    int waitTimeMinutes = 0,
  }) async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final review = await repo.postReview(
        stationId: stationId,
        rating: rating,
        comment: comment,
        authorName: authorName,
        workingStatus: workingStatus,
        waitTimeMinutes: waitTimeMinutes,
      );

      final currentReviews = List<StationReview>.from(state.reviewsByStation[stationId] ?? []);
      currentReviews.insert(0, review);
      final updatedReviews = Map<String, List<StationReview>>.from(state.reviewsByStation);
      updatedReviews[stationId] = currentReviews;

      state = state.copyWith(
        reviewsByStation: updatedReviews,
        isLoading: false,
        message: 'Review posted successfully!',
      );
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false, message: 'Failed to post review.');
      return false;
    }
  }

  /// Submit 1-tap Survei Mikro vote and immediately update local consensus state.
  Future<MicroSurveyConsensus> voteMicroSurvey({
    required String stationId,
    required String plugStatus,
    required String parkingStatus,
    required String accessDifficulty,
  }) async {
    final repo = ref.read(communityRepositoryProvider);
    final updated = await repo.voteMicroSurvey(
      stationId: stationId,
      plugStatus: plugStatus,
      parkingStatus: parkingStatus,
      accessDifficulty: accessDifficulty,
    );

    final map = Map<String, MicroSurveyConsensus>.from(state.consensusByStation);
    map[stationId] = updated;
    state = state.copyWith(consensusByStation: map);

    // If consensus triggered availability or fee change, reload stations
    if (updated.stationAutoUpdated) {
      ref.read(stationControllerProvider.notifier).loadStations();
    }

    return updated;
  }

  /// Fetch pending unverified community stations for moderation queue.
  Future<void> loadPendingStations() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(communityRepositoryProvider);
    final pending = await repo.fetchPendingStations();
    state = state.copyWith(pendingStations: pending, isLoading: false);
  }

  /// Submit a new community station.
  Future<bool> submitCommunityStation(ChargingStation station) async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final created = await repo.submitStation(station);

      final current = List<ChargingStation>.from(state.pendingStations);
      current.insert(0, created);

      state = state.copyWith(
        pendingStations: current,
        isLoading: false,
        message: 'Station submitted! It will appear on the map upon verification.',
      );
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false, message: 'Failed to submit station.');
      return false;
    }
  }

  /// Moderate a pending station (Approve onto live map or Reject).
  Future<bool> moderateStation({
    required String stationId,
    required bool approve,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final approvedStation = await repo.moderateStation(stationId, approve);

      final current = List<ChargingStation>.from(state.pendingStations)
        ..removeWhere((s) => s.id == stationId);

      state = state.copyWith(pendingStations: current, isLoading: false);

      // If approved, refresh stations map so it appears live
      if (approve && approvedStation != null) {
        ref.read(stationControllerProvider.notifier).loadStations();
      }
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

/// Global provider for CommunityController.
final communityControllerProvider =
    NotifierProvider<CommunityNotifier, CommunityState>(CommunityNotifier.new);
