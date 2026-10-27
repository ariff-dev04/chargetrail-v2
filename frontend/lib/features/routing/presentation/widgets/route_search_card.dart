import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/config/map_tile_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/route_repository.dart';
import '../../domain/route_models.dart';
import '../route_controller.dart';

/// Interactive Google-Maps-style free-text place search and battery SoC configuration card.
class RouteSearchCard extends ConsumerStatefulWidget {
  final bool? isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onPlanRouteCompleted;

  const RouteSearchCard({
    super.key,
    this.isExpanded,
    this.onToggleExpand,
    this.onPlanRouteCompleted,
  });

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
      setState(() {
        _suggestions = [];
        _activeField = null;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final results = await ref.read(routeControllerProvider.notifier).searchPlaces(query);
      if (mounted) setState(() { _suggestions = results; _activeField = field; });
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final gpsPlace = PlaceSuggestion(
        name: 'Current Location (GPS)',
        city: 'Current Location',
        state: 'Malaysia',
        latitude: pos.latitude,
        longitude: pos.longitude,
        category: 'gps',
      );
      _originCtrl.text = gpsPlace.name;
      ref.read(routeControllerProvider.notifier).setOrigin(gpsPlace);
    } catch (_) {
      final fallback = RouteRepository.defaultHubs.first;
      _originCtrl.text = fallback.name;
      ref.read(routeControllerProvider.notifier).setOrigin(fallback);
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
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route, color: AppTheme.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_shorten(state.origin.name)} ➔ ${_shorten(state.destination.name)} • ${state.startingSocPercent}% SoC',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                    Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryTeal),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Route & Battery Simulation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const MapStyleSelectorButton(),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('search_card_collapse_button'),
                    onPressed: _toggle,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                    label: const Text('Collapse', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _originCtrl,
                      decoration: InputDecoration(
                        labelText: 'Origin',
                        prefixIcon: const Icon(Icons.trip_origin, color: AppTheme.successGreen, size: 16),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.my_location, size: 16), tooltip: 'Current GPS', onPressed: _useCurrentGps),
                            if (_originCtrl.text.isNotEmpty)
                              IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _originCtrl.clear(); _onSearchChanged('', 'origin'); }),
                          ],
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => _onSearchChanged(v, 'origin'),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _destCtrl,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: const Icon(Icons.flag, color: Colors.red, size: 16),
                        suffixIcon: _destCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _destCtrl.clear(); _onSearchChanged('', 'dest'); })
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => _onSearchChanged(v, 'dest'),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_vert, color: AppTheme.primaryTeal),
                tooltip: 'Swap Origin & Destination',
                onPressed: () {
                  final tmp = _originCtrl.text;
                  _originCtrl.text = _destCtrl.text;
                  _destCtrl.text = tmp;
                  notifier.swapOriginDestination();
                },
              ),
            ],
          ),
          if (_suggestions.isNotEmpty && _activeField != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
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
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Starting Battery SoC:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${state.startingSocPercent}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
            ],
          ),
          Slider(
            value: state.startingSocPercent.toDouble(),
            min: 15,
            max: 100,
            divisions: 17,
            activeColor: AppTheme.primaryTeal,
            onChanged: (v) => notifier.setStartingSoc(v.round()),
          ),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: state.isLoading ? null : _planRoute,
              icon: state.isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 18),
              label: Text(state.isLoading ? 'Calculating Route…' : 'Plan EV Route', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
