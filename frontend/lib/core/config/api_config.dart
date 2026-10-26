import 'package:flutter/foundation.dart';

/// Centralized API endpoint configuration with automatic host resolution for Android AVD.
class ApiConfig {
  ApiConfig._();

  /// Resolves target base URL automatically:
  /// - Explicit `--dart-define=API_BASE_URL=...` override
  /// - `http://10.0.2.2:8000` on Android Emulator
  /// - `http://localhost:8000` on Web, Windows Desktop, iOS Simulator, and tests
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }
}
