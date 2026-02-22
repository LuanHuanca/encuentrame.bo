import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
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
  String toString() =>
      'ApiClientException(status=$statusCode, code=$code, message=$message, details=$details)';
}

/// Cliente REST para API Gateway (Amplify Gen1 REST).
/// Nota: tu API está montada en /api (por tu swagger).
class RestClient {
  static const String apiName = 'apic45634fb';

  String _path(String p) {
    var path = p.trim();
    if (!path.startsWith('/')) path = '/$path';
    if (path.startsWith('/api')) return path;
    return '/api$path';
  }

  Future<Map<String, dynamic>> get(
      String path, {
        Map<String, String>? queryParameters,
      }) async {
    try {
      final op = Amplify.API.get(
        _path(path),
        apiName: apiName,
        queryParameters: queryParameters,
      );
      final res = await op.response;
      return _handle(res.statusCode, res.decodeBody());
    } on ApiException catch (e) {
      throw ApiClientException(
        e.message,
        code: e.recoverySuggestion,
        details: e.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    try {
      final op = Amplify.API.post(
        _path(path),
        apiName: apiName,
        body: HttpPayload.json(body),
      );
      final res = await op.response;
      return _handle(res.statusCode, res.decodeBody());
    } on ApiException catch (e) {
      throw ApiClientException(
        e.message,
        code: e.recoverySuggestion,
        details: e.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> put(
      String path,
      Map<String, dynamic> body,
      ) async {
    try {
      final op = Amplify.API.put(
        _path(path),
        apiName: apiName,
        body: HttpPayload.json(body),
      );
      final res = await op.response;
      return _handle(res.statusCode, res.decodeBody());
    } on ApiException catch (e) {
      throw ApiClientException(
        e.message,
        code: e.recoverySuggestion,
        details: e.underlyingException?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> del(String path) async {
    try {
      final op = Amplify.API.delete(
        _path(path),
        apiName: apiName,
      );
      final res = await op.response;
      return _handle(res.statusCode, res.decodeBody());
    } on ApiException catch (e) {
      throw ApiClientException(
        e.message,
        code: e.recoverySuggestion,
        details: e.underlyingException?.toString(),
      );
    }
  }

  Map<String, dynamic> _handle(int statusCode, String raw) {
    Map<String, dynamic> json;
    try {
      json = raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      json = {'raw': raw};
    }

    if (statusCode >= 400) {
      final err = (json['error'] is Map)
          ? (json['error'] as Map).cast<String, dynamic>()
          : null;
      throw ApiClientException(
        err?['message']?.toString() ?? 'HTTP $statusCode',
        statusCode: statusCode,
        code: err?['code']?.toString(),
        details: err?['details']?.toString(),
      );
    }

    // Por si tu Lambda manda 200 con { error: {...} }
    if (json['error'] is Map) {
      final err = (json['error'] as Map).cast<String, dynamic>();
      throw ApiClientException(
        err['message']?.toString() ?? 'Error',
        statusCode: statusCode,
        code: err['code']?.toString(),
        details: err['details']?.toString(),
      );
    }

    return json;
  }
}