import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/config/map_tile_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../vehicles/presentation/vehicle_controller.dart';
import '../../data/route_repository.dart';
import '../../domain/route_models.dart';
import '../route_controller.dart';

/// ABRP-inspired bottom-sheet route search panel with expandable vehicle telemetry & stop strategies.
class RouteSearchCard extends ConsumerStatefulWidget {
  final bool? isExpanded;
  final VoidCallback? onToggleExpand, onPlanRouteCompleted;

  const RouteSearchCard({super.key, this.isExpanded, this.onToggleExpand, this.onPlanRouteCompleted});

  @override
  ConsumerState<RouteSearchCard> createState() => _RouteSearchCardState();
}

class _RouteSearchCardState extends ConsumerState<RouteSearchCard> {
  final TextEditingController _originCtrl = TextEditingController();
  final TextEditingController _destCtrl = TextEditingController();
  bool _localExpanded = true;
  String? _activeField;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounceTimer;

  bool get _isExpanded => widget.isExpanded ?? _localExpanded;

  void _toggle() {
    if (widget.onToggleExpand != null) {
      widget.onToggleExpand!();
    } else {
      setState(() => _localExpanded = !_localExpanded);
    }
  }

  @override
  void initState() {
    super.initState();
    final state = ref.read(routeControllerProvider);
    _originCtrl.text = state.origin.name;
    _destCtrl.text = state.destination.name;
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, String field) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _suggestions = []; _activeField = null; });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final res = await ref.read(routeControllerProvider.notifier).searchPlaces(query);
      if (mounted) setState(() { _suggestions = res; _activeField = field; });
    });
  }

  void _selectSuggestion(PlaceSuggestion place) {
    final notifier = ref.read(routeControllerProvider.notifier);
    if (_activeField == 'origin') {
      _originCtrl.text = place.name;
      notifier.setOrigin(place);
    } else {
      _destCtrl.text = place.name;
      notifier.setDestination(place);
    }
    setState(() { _suggestions = []; _activeField = null; });
  }

  Future<void> _useCurrentGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final p = PlaceSuggestion(name: 'Current Location (GPS)', city: 'Current Location', state: 'Malaysia', latitude: pos.latitude, longitude: pos.longitude, category: 'gps');
      _originCtrl.text = p.name;
      ref.read(routeControllerProvider.notifier).setOrigin(p);
    } catch (_) {
      final f = RouteRepository.defaultHubs.first;
      _originCtrl.text = f.name;
      ref.read(routeControllerProvider.notifier).setOrigin(f);
    }
    setState(() { _suggestions = []; _activeField = null; });
  }

  Future<void> _planRoute() async {
    FocusScope.of(context).unfocus();
    setState(() { _suggestions = []; _activeField = null; });
    await ref.read(routeControllerProvider.notifier).calculateRoute();
    if (widget.onPlanRouteCompleted != null) {
      widget.onPlanRouteCompleted!();
    } else if (mounted) {
      setState(() => _localExpanded = false);
    }
  }

  String _shorten(String text) {
    final clean = text.split('/').first.trim();
    return clean.length > 14 ? '${clean.substring(0, 14)}…' : clean;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeControllerProvider);
    final notifier = ref.read(routeControllerProvider.notifier);
    final vehicle = ref.watch(vehicleControllerProvider).activeVehicle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isExpanded) {
      return GestureDetector(
        key: const Key('collapsed_search_pill'),
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route, color: AppTheme.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text('${_shorten(state.origin.name)} ➔ ${_shorten(state.destination.name)} • ${state.startingSocPercent}% SoC', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                  Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryTeal),
                ]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 8),
          if (state.isLoading) ...[
            const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(2)), child: LinearProgressIndicator(minHeight: 3, backgroundColor: Colors.transparent, color: AppTheme.primaryTeal)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Route & Battery Simulation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Row(children: [
                const MapStyleSelectorButton(),
                const SizedBox(width: 4),
                TextButton.icon(
                  key: const Key('search_card_collapse_button'),
                  onPressed: _toggle,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                  label: const Text('Collapse', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          _buildInputBox(
            controller: _originCtrl, label: 'Origin', icon: Icons.trip_origin, iconColor: AppTheme.successGreen,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.my_location, size: 16), tooltip: 'Current GPS', onPressed: _useCurrentGps),
              if (_originCtrl.text.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _originCtrl.clear(); _onSearchChanged('', 'origin'); }),
            ]),
            onChanged: (v) => _onSearchChanged(v, 'origin'), isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildInputBox(
            controller: _destCtrl, label: 'Destination', icon: Icons.flag, iconColor: Colors.red,
            trailing: _destCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _destCtrl.clear(); _onSearchChanged('', 'dest'); }) : null,
            onChanged: (v) => _onSearchChanged(v, 'dest'), isDark: isDark,
          ),
          if (_suggestions.isNotEmpty && _activeField != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: Material(
                color: Colors.transparent,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (ctx, i) {
                    final item = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, size: 16, color: AppTheme.primaryTeal),
                      title: Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.city}, ${item.state}', style: const TextStyle(fontSize: 10)),
                      onTap: () => _selectSuggestion(item),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  final tmp = _originCtrl.text;
                  _originCtrl.text = _destCtrl.text;
                  _destCtrl.text = tmp;
                  notifier.swapOriginDestination();
                },
                icon: const Icon(Icons.swap_vert_rounded, size: 16, color: AppTheme.primaryTeal),
                label: const Text('Swap / Reverse', style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: notifier.toggleMoreOptions,
                icon: Icon(state.isMoreOptionsExpanded ? Icons.keyboard_arrow_up : Icons.more_horiz_rounded, size: 16),
                label: Text(state.isMoreOptionsExpanded ? 'less' : 'more options', style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: state.isMoreOptionsExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.directions_car_rounded, size: 16, color: AppTheme.primaryTeal),
                              const SizedBox(width: 6),
                              Expanded(child: Text('${vehicle.brand} ${vehicle.modelName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Icon(Icons.battery_charging_full_rounded, size: 16, color: _getSocColor(state.startingSocPercent)),
                              const SizedBox(width: 4),
                              Text('${state.startingSocPercent}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getSocColor(state.startingSocPercent))),
                            ]),
                            const SizedBox(height: 6),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF22C55E)]),
                                  ),
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: Colors.transparent, inactiveTrackColor: Colors.transparent),
                                  child: Slider(value: state.startingSocPercent.toDouble(), min: 15, max: 100, divisions: 17, onChanged: (v) => notifier.setStartingSoc(v.round())),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Destination arrival SoC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text('${state.targetArrivalSocPct.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                      ]),
                      Slider(value: state.targetArrivalSocPct, min: 5, max: 50, divisions: 9, activeColor: AppTheme.primaryTeal, onChanged: (v) => notifier.setTargetArrivalSoc(v)),
                      const Text('Charger Stops', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _buildStrategyTile('few_long', 'Few but\nlong stops', state.stopStrategy, notifier, isDark),
                        const SizedBox(width: 6),
                        _buildStrategyTile('quickest', 'Quickest\narrival', state.stopStrategy, notifier, isDark),
                        const SizedBox(width: 6),
                        _buildStrategyTile('short_many', 'Short but\nmany stops', state.stopStrategy, notifier, isDark),
                      ]),
                      const SizedBox(height: 8),
                      FilterChip(
                        label: const Text('Prefer Highway R&R / Easy Access', style: TextStyle(fontSize: 11)),
                        selected: state.preferEasyAccess,
                        onSelected: (v) => notifier.togglePreferEasyAccess(v),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _originCtrl.clear();
                    _destCtrl.clear();
                    notifier.clearRouteInputs();
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: state.isLoading ? null : _planRoute,
                  icon: state.isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded, size: 18),
                  label: Text(state.isLoading ? 'Calculating…' : 'Plan EV Route', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller, required String label, required IconData icon,
    required Color iconColor, required ValueChanged<String> onChanged, required bool isDark, Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: label, border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              onChanged: onChanged,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildStrategyTile(String key, String label, String current, RouteNotifier notifier, bool isDark) {
    final sel = current == key;
    return Expanded(
      child: InkWell(
        onTap: () => notifier.setStopStrategy(key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primaryTeal.withValues(alpha: 0.15) : (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.25)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? AppTheme.primaryTeal : null, height: 1.2)),
        ),
      ),
    );
  }

  Color _getSocColor(int soc) {
    if (soc <= 25) return const Color(0xFFEF4444);
    if (soc <= 55) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }
}
