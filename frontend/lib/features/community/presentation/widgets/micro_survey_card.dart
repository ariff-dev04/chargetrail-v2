import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/auth_controller.dart';
import 'package:frontend/features/community/domain/community_models.dart';
import 'package:frontend/features/community/presentation/community_controller.dart';

/// Card providing 1-tap Survei Mikro consensus voting and driver visit reviews.
class MicroSurveyCard extends ConsumerStatefulWidget {
  final String stationId;

  const MicroSurveyCard({super.key, required this.stationId});

  @override
  ConsumerState<MicroSurveyCard> createState() => _MicroSurveyCardState();
}

class _MicroSurveyCardState extends ConsumerState<MicroSurveyCard> {
  String _plugStatus = 'working';
  String _parkingStatus = 'paid';
  final String _accessDifficulty = 'easy';

  bool _isWritingReview = false;
  int _rating = 5;
  final int _waitTime = 0;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(communityControllerProvider.notifier).loadStationCommunityData(widget.stationId);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityControllerProvider);
    final consensus = state.consensusByStation[widget.stationId] ??
        MicroSurveyConsensus(stationId: widget.stationId);
    final reviews = state.reviewsByStation[widget.stationId] ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Survei Mikro Consensus Header & Badge (KF16)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2D28) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.how_to_vote, size: 18, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  const Text(
                    'Survei Mikro Community Consensus',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${consensus.totalVotes} votes',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: consensus.hasConsensus ? AppTheme.primaryTeal : Colors.orange[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  consensus.hasConsensus
                      ? 'Consensus: ${consensus.summaryBadgeText}'
                      : 'Voting in Progress (3 votes needed for consensus)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),

              // 1-Tap Voting Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _voteChoiceChip('Plugs: Working', 'working', _plugStatus, (v) => setState(() => _plugStatus = v)),
                  _voteChoiceChip('Plugs: Broken', 'out_of_order', _plugStatus, (v) => setState(() => _plugStatus = v)),
                  _voteChoiceChip('Parking: Free', 'free', _parkingStatus, (v) => setState(() => _parkingStatus = v)),
                  _voteChoiceChip('Parking: Paid', 'paid', _parkingStatus, (v) => setState(() => _parkingStatus = v)),
                ],
              ),
              const SizedBox(height: 8),

              FilledButton.tonalIcon(
                onPressed: () {
                  ref.read(communityControllerProvider.notifier).voteMicroSurvey(
                        stationId: widget.stationId,
                        plugStatus: _plugStatus,
                        parkingStatus: _parkingStatus,
                        accessDifficulty: _accessDifficulty,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Survei Mikro vote recorded!')),
                  );
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Submit 1-Tap Survey Vote'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Driver Reviews & Check-Ins (KF07)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Driver Check-Ins (${reviews.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isWritingReview = !_isWritingReview),
              icon: Icon(_isWritingReview ? Icons.close : Icons.edit, size: 14),
              label: Text(_isWritingReview ? 'Cancel' : 'Write Review'),
            ),
          ],
        ),

        if (_isWritingReview) ...[
          _buildReviewForm(context),
          const SizedBox(height: 12),
        ],

        if (reviews.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No reviews yet. Be the first to check in!', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ] else ...[
          ...reviews.map((r) => _buildReviewItem(r, isDark)),
        ],
      ],
    );
  }

  Widget _voteChoiceChip(String label, String value, String selected, ValueChanged<String> onSelected) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildReviewForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Rating: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ...List.generate(5, (index) {
                final starNum = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starNum),
                  child: Icon(
                    starNum <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Share queue time, charging speed, or bay tips...',
              contentPadding: EdgeInsets.all(8),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              if (_commentCtrl.text.trim().isEmpty) return;
              final user = ref.read(authControllerProvider).currentUser;
              final author = user?.fullName ?? 'EV Driver';

              ref.read(communityControllerProvider.notifier).postReview(
                    stationId: widget.stationId,
                    rating: _rating,
                    comment: _commentCtrl.text.trim(),
                    authorName: author,
                    waitTimeMinutes: _waitTime,
                  );

              setState(() {
                _isWritingReview = false;
                _commentCtrl.clear();
              });
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: const Text('Post Check-In'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(StationReview r, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2B26) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' ${r.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.comment, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
