import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';

/// Test helper providing a Dio mock adapter for AuthRepository testing.
class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

/// Helper instantiating an AuthRepository wired to a mock Dio adapter.
AuthRepository createMockAuthRepository(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio()..httpClientAdapter = MockHttpClientAdapter(handler);
  return AuthRepository(dio: dio);
}

/// Response builder for JSON responses in tests.
ResponseBody jsonResponseBody(dynamic body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Matcher asserting an Exception containing a specific substring is thrown.
Matcher throwsExceptionWith(String message) {
  return throwsA(
    predicate(
      (e) => e is Exception && e.toString().contains(message),
      'an Exception containing "$message"',
    ),
  );
}

/// Fixture for user JSON payload in auth tests.
Map<String, dynamic> mockUserJson({
  String id = 'u-test-1',
  String email = 'driver@chargetrail.my',
  String fullName = 'Driver Test',
  String preferredConnector = 'CCS2',
}) => {
  'id': id,
  'email': email,
  'full_name': fullName,
  'preferred_connector': preferredConnector,
  'saved_station_ids': <String>[],
};
