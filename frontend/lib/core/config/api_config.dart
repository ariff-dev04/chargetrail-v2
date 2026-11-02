import 'package:flutter/foundation.dart';

/// Centralized API endpoint configuration with automatic host resolution.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (kIsWeb && Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
      return Uri.base.origin;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://localhost:8000';
  }
}
