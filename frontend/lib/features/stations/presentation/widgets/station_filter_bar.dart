import 'package:flutter/material.dart';
import '../../domain/station_model.dart';

/// Horizontal filtering component providing quick chip toggles and keyword search.
class StationFilterBar extends StatelessWidget {
  final StationFilter activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleConnector;
  final ValueChanged<double> onToggleMinKw;
  final VoidCallback onToggle24Hours;
  final ValueChanged<String> onToggleAmenity;
  final VoidCallback onReset;

  const StationFilterBar({
    super.key,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onToggleConnector,
    required this.onToggleMinKw,
    required this.onToggle24Hours,
    required this.onToggleAmenity,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16221E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Input Field
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search station, operator, mall...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: activeFilter.searchQuery != null &&
                      activeFilter.searchQuery!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => onSearchChanged(''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2C3E36) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2C3E36) : const Color(0xFFE2E8F0),
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E2D28) : const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Filter Chips Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Reset Button Pill
                if (activeFilter.hasActiveFilters) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
                      onPressed: onReset,
                      backgroundColor: isDark
                          ? const Color(0xFF3B2D2D)
                          : const Color(0xFFFEE2E2),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                      side: const BorderSide(color: Color(0xFFF87171)),
                    ),
                  ),
                ],

                // Fast Connector Standards
                _buildChip(
                  label: 'CCS2',
                  isSelected: activeFilter.connectorType == 'CCS2',
                  onSelected: () => onToggleConnector('CCS2'),
                ),
                _buildChip(
                  label: 'Type 2',
                  isSelected: activeFilter.connectorType == 'Type 2',
                  onSelected: () => onToggleConnector('Type 2'),
                ),
                _buildChip(
                  label: 'CHAdeMO',
                  isSelected: activeFilter.connectorType == 'CHAdeMO',
                  onSelected: () => onToggleConnector('CHAdeMO'),
                ),

                // Power Rating Filter (120kW+ Ultra-Fast)
                _buildChip(
                  label: '120kW+ Fast',
                  isSelected: activeFilter.minKw == 120.0,
                  onSelected: () => onToggleMinKw(120.0),
                  icon: Icons.bolt,
                ),

                // 24-Hours Accessibility
                _buildChip(
                  label: '24 Hours',
                  isSelected: activeFilter.only24Hours,
                  onSelected: onToggle24Hours,
                  icon: Icons.access_time,
                ),

                // Amenity (Dining)
                _buildChip(
                  label: 'Dining',
                  isSelected: activeFilter.amenity == 'Dining',
                  onSelected: () => onToggleAmenity('Dining'),
                  icon: Icons.restaurant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: icon != null ? Icon(icon, size: 14) : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
