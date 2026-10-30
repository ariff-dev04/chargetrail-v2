import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/community_repository.dart';
import '../community_controller.dart';

/// Tab presenting pending community-submitted stations and edit proposals for moderation.
class ModerationQueueTab extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const ModerationQueueTab({super.key, required this.scrollController});

  @override
  ConsumerState<ModerationQueueTab> createState() => _ModerationQueueTabState();
}

class _ModerationQueueTabState extends ConsumerState<ModerationQueueTab> {
  List<Map<String, dynamic>> _pendingEdits = [];

  @override
  void initState() {
    super.initState();
    _loadPendingEdits();
  }

  Future<void> _loadPendingEdits() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getKeys().where((k) => k.startsWith('chargetrail_edits_v1_'));
      final edits = <Map<String, dynamic>>[];
      for (final k in keys) {
        final raw = p.getString(k);
        if (raw != null) {
          final list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          edits.addAll(list.where((e) => e['status'] == 'pending'));
        }
      }
      if (mounted) setState(() => _pendingEdits = edits);
    } catch (_) {}
  }

  Future<void> _moderateEdit(String editId, bool approve) async {
    await CommunityRepository().voteOnStationEdit(editId, vote: approve ? 'confirm' : 'reject', fastTrackApprove: approve);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve ? '✅ Station edit approved & published live!' : '❌ Edit proposal rejected.'),
      backgroundColor: approve ? AppTheme.successGreen : Colors.red,
    ));
    _loadPendingEdits();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityControllerProvider);
    final pendingStations = state.pendingStations;

    if (pendingStations.isEmpty && _pendingEdits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, size: 48, color: Colors.green[400]),
              const SizedBox(height: 12),
              const Text('Moderation Queue Empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('All community submitted stations & edits have been verified.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_pendingEdits.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Text('Pending Station Edits (${_pendingEdits.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706))),
              ],
            ),
            const SizedBox(height: 8),
            ..._pendingEdits.map((edit) {
              final editId = edit['id']?.toString() ?? '';
              final level = edit['parking_level'];
              final price = edit['price_per_kwh'];
              final power = edit['max_power_kw'];
              final desc = edit['description'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: const Color(0xFFFEF3C7),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Suggested Charger Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF78350F))),
                          Text('${edit['confirm_votes'] ?? 0}/3 Votes', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (level != null) 'Level: $level',
                          if (price != null) 'Tariff: RM ${price.toStringAsFixed(2)}/kWh',
                          if (power != null) 'Power: ${power.toInt()}kW',
                          if (desc != null && desc.isNotEmpty) 'Access: $desc',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _moderateEdit(editId, false),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _moderateEdit(editId, true),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.successGreen, visualDensity: VisualDensity.compact),
                            child: const Text('Fast-Track Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 20),
          ],
          if (pendingStations.isNotEmpty) ...[
            Text('Pending Station Submissions (${pendingStations.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...pendingStations.map((station) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Pending', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${station.city} • ${station.maxPowerKw.toInt()} kW • Level: ${station.parkingLevel ?? "Ground"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (station.howToAccess.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Access: ${station.howToAccess.first.instruction}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => ref.read(communityControllerProvider.notifier).moderateStation(stationId: station.id, approve: false),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => ref.read(communityControllerProvider.notifier).moderateStation(stationId: station.id, approve: true),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.successGreen),
                            child: const Text('Approve & Publish'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
