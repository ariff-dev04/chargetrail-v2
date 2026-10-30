import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stations/domain/station_model.dart';
import '../../data/community_repository.dart';

typedef StationModel = ChargingStation;

/// Modal bottom sheet allowing drivers to suggest edits for charger access, tariff, and status (KF06).
class SuggestStationEditSheet extends StatefulWidget {
  final ChargingStation station;
  final VoidCallback onSubmitted;

  const SuggestStationEditSheet({super.key, required this.station, required this.onSubmitted});

  static void show(BuildContext context, ChargingStation station, {VoidCallback? onSubmitted}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestStationEditSheet(station: station, onSubmitted: onSubmitted ?? () {}),
    );
  }

  @override
  State<SuggestStationEditSheet> createState() => _SuggestStationEditSheetState();
}

class _SuggestStationEditSheetState extends State<SuggestStationEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _parkingLevel;
  late TextEditingController _descCtrl, _priceCtrl, _powerCtrl;
  late Set<String> _selectedAmenities;
  late bool _isOperational;
  bool _isSubmitting = false;

  static const List<String> _kParkingLevels = [
    'Highway R&R / Open Bay', 'Open Public Bay', 'Multi-Storey / Indoor Carpark',
  ];
  static const List<String> _kAvailableAmenities = [
    'Restroom', 'Dining', 'Shopping', '24/7 Security', 'Surau', 'Wi-Fi',
  ];

  @override
  void initState() {
    super.initState();
    final st = widget.station;
    _parkingLevel = _kParkingLevels.contains(st.parkingLevel) ? st.parkingLevel! : _kParkingLevels.first;
    _descCtrl = TextEditingController(text: st.description ?? '');
    _priceCtrl = TextEditingController(text: st.chargingCostMyr > 0 ? st.chargingCostMyr.toStringAsFixed(2) : '1.40');
    _powerCtrl = TextEditingController(text: st.maxPowerKw.toInt().toString());
    _selectedAmenities = Set.from(st.amenities);
    _isOperational = st.isAvailable;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _powerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await CommunityRepository().suggestStationEdit(widget.station.id, {
      'parking_level': _parkingLevel,
      'description': _descCtrl.text.trim(),
      'price_per_kwh': double.tryParse(_priceCtrl.text) ?? 1.40,
      'max_power_kw': double.tryParse(_powerCtrl.text) ?? 120.0,
      'amenities': _selectedAmenities.toList(),
      'is_operational': _isOperational,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚡ Edit submitted for Community Survei Mikro verification (+5 pts)!'),
        backgroundColor: AppTheme.successGreen,
      ));
      Navigator.of(context).pop();
      widget.onSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Material(
          color: Colors.transparent,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppTheme.primaryTeal, size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Suggest an Edit • ${widget.station.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Parking & Access Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _kParkingLevels.map((lvl) {
                    final sel = _parkingLevel == lvl;
                    return ChoiceChip(
                      label: Text(lvl, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      selected: sel,
                      onSelected: (v) => setState(() => _parkingLevel = lvl),
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'How to Access / Bay & Floor Guide', hintText: 'e.g. Enter Basement B2 via Ramp A, bays opposite Pillar G4.', isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tariff (RM / kWh)', isDense: true))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _powerCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Power (kW)', isDense: true))),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Nearby Amenities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _kAvailableAmenities.map((am) {
                    final sel = _selectedAmenities.contains(am);
                    return FilterChip(
                      label: Text(am, style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (v) => setState(() { v ? _selectedAmenities.add(am) : _selectedAmenities.remove(am); }),
                    );
                  }).toList(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Charger Operational', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _isOperational,
                  activeThumbColor: AppTheme.primaryTeal,
                  onChanged: (v) => setState(() => _isOperational = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? 'Submitting…' : 'Submit Edit Proposal (+5 pts)'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Google Maps-style Community Verification banner showing active edit proposals for consensus voting.
class PendingStationEditsBanner extends StatefulWidget {
  final String stationId;
  final VoidCallback onStationMutated;

  const PendingStationEditsBanner({super.key, required this.stationId, required this.onStationMutated});

  @override
  State<PendingStationEditsBanner> createState() => _PendingStationEditsBannerState();
}

class _PendingStationEditsBannerState extends State<PendingStationEditsBanner> {
  List<Map<String, dynamic>> _edits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEdits();
  }

  Future<void> _loadEdits() async {
    final res = await CommunityRepository().fetchPendingStationEdits(widget.stationId);
    if (mounted) setState(() { _edits = res; _isLoading = false; });
  }

  Future<void> _vote(String editId, String voteType, {bool fastTrack = false}) async {
    final res = await CommunityRepository().voteOnStationEdit(editId, vote: voteType, fastTrackApprove: fastTrack);
    if (!mounted) return;

    if (res['status'] == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Community consensus reached! Station updated live.'), backgroundColor: AppTheme.successGreen));
      widget.onStationMutated();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote recorded ($voteType). Thank you for verifying!')));
    }
    _loadEdits();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _edits.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: Column(
        children: _edits.map((edit) {
          final editId = edit['id']?.toString() ?? '';
          final confirms = edit['confirm_votes'] ?? 0;
          final proposedLevel = edit['parking_level'];
          final proposedDesc = edit['description'];
          final proposedPrice = edit['price_per_kwh'];
          final proposedPower = edit['max_power_kw'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2211) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rate_review_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Community Verification Needed (Survei Mikro)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)))),
                    Text('$confirms/3 Votes', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (proposedLevel != null) 'Level: $proposedLevel',
                    if (proposedPrice != null) 'Tariff: RM ${proposedPrice.toStringAsFixed(2)}/kWh',
                    if (proposedPower != null) 'Power: ${proposedPower.toInt()}kW',
                    if (proposedDesc != null && proposedDesc.isNotEmpty) 'Access: $proposedDesc',
                  ].join(' • '),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.amber[100] : const Color(0xFF78350F)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _vote(editId, 'confirm'),
                      icon: const Icon(Icons.thumb_up_alt_rounded, size: 14),
                      label: Text('Confirm ($confirms/3)', style: const TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _vote(editId, 'reject'),
                      icon: const Icon(Icons.thumb_down_alt_outlined, size: 14),
                      label: const Text('Reject', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _vote(editId, 'confirm', fastTrack: true),
                      icon: const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primaryTeal),
                      label: const Text('Fast-Track', style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
