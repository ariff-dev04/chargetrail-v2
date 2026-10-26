import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../stations/domain/station_model.dart';
import 'community_controller.dart';

/// Modal sheet providing community station submission and admin moderation queue.
class SubmitStationSheet extends ConsumerStatefulWidget {
  const SubmitStationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubmitStationSheet(),
    );
  }

  @override
  ConsumerState<SubmitStationSheet> createState() => _SubmitStationSheetState();
}

class _SubmitStationSheetState extends ConsumerState<SubmitStationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Fields
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _parkingLevelCtrl = TextEditingController();
  final _accessStepCtrl = TextEditingController();
  double _kw = 60.0;
  String _connector = 'CCS2';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(communityControllerProvider.notifier).loadPendingStations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _parkingLevelCtrl.dispose();
    _accessStepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryTeal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryTeal,
                tabs: const [
                  Tab(icon: Icon(Icons.add_location_alt), text: 'Submit Charger'),
                  Tab(icon: Icon(Icons.admin_panel_settings), text: 'Moderation Queue'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSubmissionTab(context, scrollController),
                    _buildModerationTab(context, scrollController, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmissionTab(BuildContext context, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Contribute Hidden Charger (KF06)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Found a new charger in an underground carpark or mall? Submit it here to help Malaysian EV drivers.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Station Name *', hintText: 'e.g. Bangsar Shopping Centre B2'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cityCtrl,
          decoration: const InputDecoration(labelText: 'City *', hintText: 'e.g. Kuala Lumpur'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(labelText: 'Address', hintText: 'e.g. 285, Jalan Maarof, Bangsar'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _parkingLevelCtrl,
          decoration: const InputDecoration(labelText: 'Parking Level & Pillar (Crucial)', hintText: 'e.g. Basement B2, Pillar C12'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _accessStepCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Step 1 Access Instruction', hintText: 'e.g. Take right basement ramp, follow green floor paint.'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _connector,
                decoration: const InputDecoration(labelText: 'Plug Standard'),
                items: const [
                  DropdownMenuItem(value: 'CCS2', child: Text('CCS2 (DC)')),
                  DropdownMenuItem(value: 'Type 2', child: Text('Type 2 (AC)')),
                  DropdownMenuItem(value: 'CHAdeMO', child: Text('CHAdeMO')),
                ],
                onChanged: (v) => v != null ? setState(() => _connector = v) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: _kw,
                decoration: const InputDecoration(labelText: 'Power Output'),
                items: const [
                  DropdownMenuItem(value: 22.0, child: Text('22 kW AC')),
                  DropdownMenuItem(value: 60.0, child: Text('60 kW DC')),
                  DropdownMenuItem(value: 120.0, child: Text('120 kW Fast')),
                  DropdownMenuItem(value: 180.0, child: Text('180 kW Ultra')),
                ],
                onChanged: (v) => v != null ? setState(() => _kw = v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _submitForm,
          icon: const Icon(Icons.send),
          label: const Text('Submit Station for Verification'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal, padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_nameCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in station name and city.')),
      );
      return;
    }

    final newStation = ChargingStation(
      id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      operatorName: 'Community',
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : _cityCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: 'Malaysia',
      latitude: 3.1500,
      longitude: 101.7000,
      plugTypes: [PlugInfo(type: _connector, powerKw: _kw, count: 2)],
      maxPowerKw: _kw,
      parkingLevel: _parkingLevelCtrl.text.trim().isNotEmpty ? _parkingLevelCtrl.text.trim() : 'Basement Bay',
      howToAccess: _accessStepCtrl.text.trim().isNotEmpty
          ? [AccessStep(stepNumber: 1, instruction: _accessStepCtrl.text.trim())]
          : const [],
      source: 'community',
      isVerified: false,
    );

    ref.read(communityControllerProvider.notifier).submitCommunityStation(newStation);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Charger submitted! Check the Moderation Queue tab.')),
    );
    _tabController.animateTo(1);
  }

  Widget _buildModerationTab(BuildContext context, ScrollController scrollController, bool isDark) {
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
              const Text('Moderation Queue Empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('All community submitted stations have been verified.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      child: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
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
      },
    );
  }
}
