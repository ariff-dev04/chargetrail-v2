import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../stations/domain/station_model.dart';
import 'community_controller.dart';
import 'widgets/moderation_queue_tab.dart';

/// Modal sheet providing community station submission and admin moderation queue.
class SubmitStationSheet extends ConsumerStatefulWidget {
  final double initialLatitude;
  final double initialLongitude;

  const SubmitStationSheet({
    super.key,
    this.initialLatitude = 3.1390,
    this.initialLongitude = 101.6869,
  });

  static void show(
    BuildContext context, {
    double initialLatitude = 3.1390,
    double initialLongitude = 101.6869,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubmitStationSheet(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
      ),
    );
  }

  @override
  ConsumerState<SubmitStationSheet> createState() => _SubmitStationSheetState();
}

class _SubmitStationSheetState extends ConsumerState<SubmitStationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> kMalaysianCities = [
    'Kuala Lumpur',
    'Petaling Jaya',
    'Subang Jaya',
    'Shah Alam',
    'Cyberjaya',
    'Putrajaya',
    'Kajang',
    'Bangi',
    'Seremban',
    'Melaka',
    'Johor Bahru',
    'Ipoh',
    'Taiping',
    'George Town (Penang)',
    'Seberang Perai',
    'Kuantan',
    'Genting Highlands',
    'Alor Setar',
    'Kota Bharu',
    'Kuching',
    'Kota Kinabalu',
  ];

  late double _pinnedLat;
  late double _pinnedLng;
  String _selectedCity = 'Kuala Lumpur';

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _parkingLevelCtrl = TextEditingController();
  final _accessStepCtrl = TextEditingController();
  double _kw = 60.0;
  String _connector = 'CCS2';
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _pinnedLat = widget.initialLatitude;
    _pinnedLng = widget.initialLongitude;
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(communityControllerProvider.notifier).loadPendingStations();
      _autoResolveInitialAddress();
    });
  }

  Future<void> _autoResolveInitialAddress() async {
    final geo = await LocationService().reverseGeocode(_pinnedLat, _pinnedLng);
    if (!mounted) return;
    _applyResolvedGeo(geo);
  }

  void _applyResolvedGeo(Map<String, String> geo) {
    setState(() {
      if (geo['address'] != null && geo['address']!.isNotEmpty && _addressCtrl.text.isEmpty) {
        _addressCtrl.text = geo['address']!;
      }
      final matchedCity = kMalaysianCities.firstWhere(
        (c) => geo['city'] != null && (c.toLowerCase().contains(geo['city']!.toLowerCase()) || geo['city']!.toLowerCase().contains(c.toLowerCase())),
        orElse: () => _selectedCity,
      );
      _selectedCity = matchedCity;
    });
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isGeocoding = true);
    final loc = await LocationService().determinePosition();
    final geo = await LocationService().reverseGeocode(loc.latitude, loc.longitude);
    if (!mounted) return;

    setState(() {
      _pinnedLat = loc.latitude;
      _pinnedLng = loc.longitude;
      _isGeocoding = false;
      _applyResolvedGeo(geo);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pin & address updated: ${_pinnedLat.toStringAsFixed(4)}, ${_pinnedLng.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _parkingLevelCtrl.dispose();
    _accessStepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
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
                    _buildSubmissionTab(context, scrollController, isDark),
                    ModerationQueueTab(scrollController: scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmissionTab(BuildContext context, ScrollController scrollController, bool isDark) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Charger Pin Location Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2923) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pin_drop, color: AppTheme.primaryTeal, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('📍 Charger Pin Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isGeocoding ? null : _useCurrentGpsLocation,
                    icon: _isGeocoding
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 14),
                    label: const Text('Use My GPS', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Coordinates: ${_pinnedLat.toStringAsFixed(5)}, ${_pinnedLng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Station Name *', hintText: 'e.g. Bangsar Shopping Centre B2'),
        ),
        const SizedBox(height: 10),

        // City Selector Dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          decoration: const InputDecoration(labelText: 'City *'),
          items: kMalaysianCities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => v != null ? setState(() => _selectedCity = v) : null,
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(labelText: 'Address', hintText: 'Auto-filled or manual address'),
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Plug Standard', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'CCS2', child: Text('CCS2', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Type 2', child: Text('Type 2', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'CHAdeMO', child: Text('CHAdeMO', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) => v != null ? setState(() => _connector = v) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: _kw,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Power Output', isDense: true),
                items: const [
                  DropdownMenuItem(value: 22.0, child: Text('22 kW', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 60.0, child: Text('60 kW', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 120.0, child: Text('120 kW', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 180.0, child: Text('180 kW', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
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
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in station name.')));
      return;
    }

    final newStation = ChargingStation(
      id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      operatorName: 'Community',
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : _selectedCity,
      city: _selectedCity,
      state: 'Malaysia',
      latitude: _pinnedLat,
      longitude: _pinnedLng,
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
}
