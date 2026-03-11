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
      throw _mapApiException(error);
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
      throw _mapApiException(error);
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
      throw _mapApiException(error);
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
      throw _mapApiException(error);
    }
  }

  ApiClientException _mapApiException(ApiException error) {
    final rawDetails = [
      error.message,
      error.recoverySuggestion,
      error.underlyingException?.toString(),
    ].whereType<String>().join(' | ');

    final statusCode = _extractStatusCode(rawDetails);
    final parsedPayload = _extractJsonPayload(rawDetails);

    return ApiClientException(
      parsedPayload?['message']?.toString() ??
          error.message,
      statusCode: statusCode,
      code: parsedPayload?['code']?.toString() ??
          error.recoverySuggestion,
      details: parsedPayload?['details']?.toString() ?? rawDetails,
    );
  }

  int? _extractStatusCode(String raw) {
    final match = RegExp(r'(\b4\d{2}\b|\b5\d{2}\b)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  Map<String, dynamic>? _extractJsonPayload(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) return null;

    final jsonCandidate = raw.substring(start, end + 1);

    try {
      final decoded = jsonDecode(jsonCandidate);

      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is Map) {
          return (decoded['error'] as Map).cast<String, dynamic>();
        }
        return decoded;
      }

      if (decoded is Map) {
        final casted = decoded.cast<String, dynamic>();
        if (casted['error'] is Map) {
          return (casted['error'] as Map).cast<String, dynamic>();
        }
        return casted;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _handleResponse(int statusCode, String rawBody) {
    final json = _parseJsonMap(rawBody);

    if (statusCode >= 400) {
      final error = (json['error'] is Map)
          ? (json['error'] as Map).cast<String, dynamic>()
          : null;

      throw ApiClientException(
        error?['message']?.toString() ?? 'HTTP $statusCode',
        statusCode: statusCode,
        code: error?['code']?.toString(),
        details: error?['details']?.toString(),
      );
    }

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