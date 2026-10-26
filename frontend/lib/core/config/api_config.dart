import 'package:flutter/foundation.dart';

/// Centralized API endpoint configuration with automatic host resolution for Android.
class ApiConfig {
  ApiConfig._();

  /// Resolves target base URL automatically:
  /// - Explicit `--dart-define=API_BASE_URL=...` override
  /// - `http://127.0.0.1:8000` on Android (compatible with `adb reverse tcp:8000 tcp:8000`)
  /// - `http://localhost:8000` on Web, Windows Desktop, iOS Simulator, and tests
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://localhost:8000';
  }
}
