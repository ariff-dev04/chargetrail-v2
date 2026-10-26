import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../community_controller.dart';

/// Tab presenting pending community-submitted stations for moderation.
class ModerationQueueTab extends ConsumerWidget {
  final ScrollController scrollController;

  const ModerationQueueTab({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityControllerProvider);
    final pending = state.pendingStations;

    if (pending.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, size: 48, color: Colors.green[400]),
              const SizedBox(height: 12),
              const Text(
                'Moderation Queue Empty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'All community submitted stations have been verified.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final station = pending[index];
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
                    Expanded(
                      child: Text(
                        station.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${station.city} • ${station.maxPowerKw.toInt()} kW • Level: ${station.parkingLevel ?? "Ground"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (station.howToAccess.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Access: ${station.howToAccess.first.instruction}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => ref
                          .read(communityControllerProvider.notifier)
                          .moderateStation(stationId: station.id, approve: false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => ref
                          .read(communityControllerProvider.notifier)
                          .moderateStation(stationId: station.id, approve: true),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.successGreen),
                      child: const Text('Approve & Publish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
