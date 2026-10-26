import 'package:flutter/material.dart';

/// Centralized Material 3 styling for ChargeTrail v2.
/// Features an emerald/teal eco-mobility palette tailored for EV charging discovery.
class AppTheme {
  AppTheme._();

  // Primary Brand Colors
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color secondaryTeal = Color(0xFF26A69A);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color ultraFastColor = Color(0xFFFF7043);
  static const Color successGreen = Color(0xFF2E7D32);

  // Surface Neutral Tones
  static const Color surfaceLight = Color(0xFFF8FAF9);
  static const Color cardLight = Colors.white;
  static const Color surfaceDark = Color(0xFF121B18);
  static const Color cardDark = Color(0xFF1C2824);

  /// Light theme definition
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryTeal,
      brightness: Brightness.light,
      primary: primaryTeal,
      secondary: secondaryTeal,
      surface: surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A2E26),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        selectedColor: primaryTeal.withValues(alpha: 0.18),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  /// Dark theme definition
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryTeal,
      brightness: Brightness.dark,
      primary: secondaryTeal,
      secondary: primaryTeal,
      surface: surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        selectedColor: secondaryTeal.withValues(alpha: 0.25),
        side: const BorderSide(color: Color(0xFF2E3E37)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardDark,
        modalBackgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
