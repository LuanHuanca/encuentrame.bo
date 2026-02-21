import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../../core/constants/api_constants.dart';

class RestClient {
  String _p(String path) {
    // asegura /api + /ruta
    if (path.startsWith('/')) return '${ApiConstants.basePath}$path';
    return '${ApiConstants.basePath}/$path';
  }

  Future<Map<String, dynamic>> get(String path) async {
    final op = Amplify.API.get(
      _p(path),
      apiName: ApiConstants.restApiName,
      headers: const {'Content-Type': 'application/json'},
    );
    final res = await op.response;
    return jsonDecode(res.decodeBody()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final op = Amplify.API.put(
      _p(path),
      apiName: ApiConstants.restApiName,
      headers: const {'Content-Type': 'application/json'},
      body: HttpPayload.json(body),
    );
    final res = await op.response;
    return jsonDecode(res.decodeBody()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final op = Amplify.API.post(
      _p(path),
      apiName: ApiConstants.restApiName,
      headers: const {'Content-Type': 'application/json'},
      body: HttpPayload.json(body),
    );
    final res = await op.response;
    return jsonDecode(res.decodeBody()) as Map<String, dynamic>;
  }
}