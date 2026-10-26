import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available map layer raster styles using open-source $0 tile servers.
enum MapTileStyle {
  defaultStreet,
  satellite,
  dark;

  String get label => switch (this) {
        MapTileStyle.defaultStreet => 'Street',
        MapTileStyle.satellite => 'Satellite',
        MapTileStyle.dark => 'Dark',
      };

  IconData get icon => switch (this) {
        MapTileStyle.defaultStreet => Icons.map_outlined,
        MapTileStyle.satellite => Icons.satellite_alt_outlined,
        MapTileStyle.dark => Icons.dark_mode_outlined,
      };

  String get urlTemplate => switch (this) {
        MapTileStyle.defaultStreet =>
          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        MapTileStyle.satellite =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        MapTileStyle.dark =>
          'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      };
}

/// Notifier managing active map raster style.
class MapTileStyleNotifier extends Notifier<MapTileStyle> {
  @override
  MapTileStyle build() => MapTileStyle.defaultStreet;

  void setStyle(MapTileStyle style) {
    state = style;
  }
}

/// Riverpod state provider storing active map raster style.
final mapTileStyleProvider =
    NotifierProvider<MapTileStyleNotifier, MapTileStyle>(MapTileStyleNotifier.new);

/// Compact button allowing users to switch map layers (Street, Satellite, Dark).
class MapStyleSelectorButton extends ConsumerWidget {
  const MapStyleSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStyle = ref.watch(mapTileStyleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<MapTileStyle>(
      tooltip: 'Switch Map Style',
      initialValue: currentStyle,
      onSelected: (style) {
        ref.read(mapTileStyleProvider.notifier).setStyle(style);
      },
      itemBuilder: (context) => MapTileStyle.values.map((style) {
        final isSelected = style == currentStyle;
        return PopupMenuItem<MapTileStyle>(
          value: style,
          child: Row(
            children: [
              Icon(style.icon, size: 18, color: isSelected ? const Color(0xFF00897B) : null),
              const SizedBox(width: 8),
              Text(
                style.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF00897B) : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2824) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentStyle.icon, size: 16, color: const Color(0xFF00897B)),
            const SizedBox(width: 4),
            Text(
              currentStyle.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
