import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';

class ApiClientException implements Exception {
  ApiClientException(
      this.message, {
        this.statusCode,
        this.code,
        this.details,
      });

  final String message;
  final int? statusCode;
  final String? code;
  final String? details;

  @override
  String toString() {
    return 'ApiClientException('
        'status=$statusCode, '
        'code=$code, '
        'message=$message, '
        'details=$details'
        ')';
  }
}

/// REST client for the API Gateway configured in Amplify.
///
/// The backend is mounted under `/api`, so every relative path is normalized
/// to start with `/api/...`.
class RestClient {
  static const String apiName = 'apic45634fb';

  String _normalizePath(String path) {
    var normalized = path.trim();

    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    if (normalized.startsWith('/api')) {
      return normalized;
    }

    return '/api$normalized';
  }

  Future<Map<String, dynamic>> get(
      String path, {
        Map<String, String>? queryParameters,
      }) async {
    try {
      final operation = Amplify.API.get(
        _normalizePath(path),
        apiName: apiName,
        queryParameters: queryParameters,
      );

      final response = await operation.response;
      return _handleResponse(response.statusCode, response.decodeBody());
    } on ApiException catch (error) {
      throw ApiClientException(
        error.message,
        code: error.recoverySuggestion,
        details: error.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    try {
      final operation = Amplify.API.post(
        _normalizePath(path),
        apiName: apiName,
        body: HttpPayload.json(body),
      );

      final response = await operation.response;
      return _handleResponse(response.statusCode, response.decodeBody());
    } on ApiException catch (error) {
      throw ApiClientException(
        error.message,
        code: error.recoverySuggestion,
        details: error.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> put(
      String path,
      Map<String, dynamic> body,
      ) async {
    try {
      final operation = Amplify.API.put(
        _normalizePath(path),
        apiName: apiName,
        body: HttpPayload.json(body),
      );

      final response = await operation.response;
      return _handleResponse(response.statusCode, response.decodeBody());
    } on ApiException catch (error) {
      throw ApiClientException(
        error.message,
        code: error.recoverySuggestion,
        details: error.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> del(String path) async {
    try {
      final operation = Amplify.API.delete(
        _normalizePath(path),
        apiName: apiName,
      );

      final response = await operation.response;
      return _handleResponse(response.statusCode, response.decodeBody());
    } on ApiException catch (error) {
      throw ApiClientException(
        error.message,
        code: error.recoverySuggestion,
        details: error.underlyingException?.toString(),
      );
    }
  }

  Map<String, dynamic> _handleResponse(int statusCode, String rawBody) {
    final json = _parseJsonMap(rawBody);

    if (statusCode >= 400) {
      final error =
      (json['error'] is Map) ? (json['error'] as Map).cast<String, dynamic>() : null;

      throw ApiClientException(
        error?['message']?.toString() ?? 'HTTP $statusCode',
        statusCode: statusCode,
        code: error?['code']?.toString(),
        details: error?['details']?.toString(),
      );
    }

    // Defensive fallback in case the backend responds with 200 but embeds
    // an error payload.
    if (json['error'] is Map) {
      final error = (json['error'] as Map).cast<String, dynamic>();

      throw ApiClientException(
        error['message']?.toString() ?? 'Unknown API error',
        statusCode: statusCode,
        code: error['code']?.toString(),
        details: error['details']?.toString(),
      );
    }

    return json;
  }

  Map<String, dynamic> _parseJsonMap(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }

      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'raw': rawBody};
    }
  }
}