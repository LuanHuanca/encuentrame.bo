import '../../../core/constants/api_constants.dart';
import '../../api/rest_client.dart';

/// High-level API service for the MVP.
///
/// This version is intentionally minimal:
/// - health check
/// - public buyer search
/// - public stall products
///
/// Orders, cart, bootstrap flows and other e-commerce features were removed
/// because they are outside the current MVP.
class EncuentrameApiService {
  EncuentrameApiService({RestClient? client})
      : _client = client ?? RestClient();

  final RestClient _client;

  Future<Map<String, dynamic>> health() {
    return _client.get(ApiConstants.health);
  }

  Future<Map<String, dynamic>> listOpenStallsNear({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int limit = 30,
    String? query,
    bool includeProducts = false,
    int productsLimit = 6,
  }) {
    final queryParameters = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
      'includeProducts': includeProducts ? '1' : '0',
      'productsLimit': productsLimit.toString(),
    };

    final trimmedQuery = query?.trim() ?? '';
    if (trimmedQuery.isNotEmpty) {
      queryParameters['q'] = trimmedQuery;
    }

    return _client.get(
      ApiConstants.marketOpenStalls,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> listStallProductsPublic({
    required String stallId,
    String? query,
    int limit = 50,
  }) {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
    };

    final trimmedQuery = query?.trim() ?? '';
    if (trimmedQuery.isNotEmpty) {
      queryParameters['q'] = trimmedQuery;
    }

    return _client.get(
      ApiConstants.marketStallProducts(stallId),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> searchProductsNear({
    required double lat,
    required double lng,
    required String query,
    double radiusKm = 10,
    int limit = 30,
  }) {
    final queryParameters = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'q': query.trim(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
    };

    return _client.get(
      ApiConstants.marketSearchProducts,
      queryParameters: queryParameters,
    );
  }
}