import '../../../core/constants/api_constants.dart';
import '../../api/rest_client.dart';

class EncuentrameApiService {
  EncuentrameApiService({RestClient? client})
      : _client = client ?? RestClient();

  final RestClient _client;

  Future<Map<String, dynamic>> health() {
    return _client.get(ApiConstants.health);
  }

  Future<Map<String, dynamic>> getMarketCategories() {
    return _client.get(ApiConstants.marketCategories);
  }

  Future<Map<String, dynamic>> listOpenStallsNear({
    double? lat,
    double? lng,
    double radiusKm = 10,
    int limit = 50,
    bool includeProducts = false,
    int productsLimit = 6,
    String? category,
  }) {
    final queryParameters = <String, String>{
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
      'includeProducts': includeProducts ? '1' : '0',
      'productsLimit': productsLimit.toString(),
    };

    if (lat != null) {
      queryParameters['lat'] = lat.toString();
    }

    if (lng != null) {
      queryParameters['lng'] = lng.toString();
    }

    final trimmedCategory = category?.trim() ?? '';
    if (trimmedCategory.isNotEmpty && trimmedCategory != 'Todos') {
      queryParameters['category'] = trimmedCategory;
    }

    return _client.get(
      ApiConstants.marketOpenStalls,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> searchProductsNear({
    double? lat,
    double? lng,
    required String query,
    double radiusKm = 10,
    int limit = 50,
    String? category,
  }) {
    final queryParameters = <String, String>{
      'q': query.trim(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
    };

    if (lat != null) {
      queryParameters['lat'] = lat.toString();
    }

    if (lng != null) {
      queryParameters['lng'] = lng.toString();
    }

    final trimmedCategory = category?.trim() ?? '';
    if (trimmedCategory.isNotEmpty && trimmedCategory != 'Todos') {
      queryParameters['category'] = trimmedCategory;
    }

    return _client.get(
      ApiConstants.marketSearchProducts,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> getMarketStallDetail({
    required String stallId,
    double? userLat,
    double? userLng,
  }) {
    final queryParameters = <String, String>{};

    if (userLat != null) {
      queryParameters['lat'] = userLat.toString();
    }

    if (userLng != null) {
      queryParameters['lng'] = userLng.toString();
    }

    return _client.get(
      ApiConstants.marketStallDetail(stallId),
      queryParameters:
      queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<Map<String, dynamic>> listMyStalls() {
    return _client.get(ApiConstants.stalls);
  }

  Future<Map<String, dynamic>> createStall({
    required String name,
    String? category,
    String? description,
  }) {
    return _client.post(
      ApiConstants.stalls,
      {
        'name': name.trim(),
        'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
        'description': (description ?? '').trim(),
      },
    );
  }

  Future<Map<String, dynamic>> updateStall({
    required String stallId,
    required String name,
    String? category,
    String? description,
  }) {
    return _client.put(
      ApiConstants.stallById(stallId),
      {
        'name': name.trim(),
        'category': (category ?? '').trim().isEmpty ? null : category?.trim(),
        'description': (description ?? '').trim(),
      },
    );
  }

  Future<Map<String, dynamic>> deleteStall(String stallId) {
    return _client.del(ApiConstants.stallById(stallId));
  }

  Future<Map<String, dynamic>> openStall({
    required String stallId,
    required String stallName,
    required double lat,
    required double lng,
    required double accuracy,
    required String stallPhotoKey,
    required String productsPhotoKey,
    required String inventoryText,
    required String idempotencyKey,
  }) {
    return _client.post(
      ApiConstants.stallsOpen,
      {
        'stallId': stallId,
        'stallName': stallName,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'stallPhotoKey': stallPhotoKey,
        'productsPhotoKey': productsPhotoKey,
        'inventoryText': inventoryText.trim(),
        'idempotencyKey': idempotencyKey,
      },
    );
  }

  Future<Map<String, dynamic>> closeStall(String stallId) {
    return _client.post(ApiConstants.stallClose(stallId), {});
  }

  Future<Map<String, dynamic>> getCurrentStallOpening(String stallId) {
    return _client.get(ApiConstants.stallCurrent(stallId));
  }

  Future<Map<String, dynamic>> getStallProducts(String stallId) {
    return _client.get(ApiConstants.stallProducts(stallId));
  }

  Future<Map<String, dynamic>> updateStallProduct({
    required String stallId,
    required String productId,
    required Map<String, dynamic> payload,
  }) {
    return _client.put(
      ApiConstants.stallProductById(stallId, productId),
      payload,
    );
  }

  Future<Map<String, dynamic>> getMyProfile() {
    return _client.get(ApiConstants.userMe);
  }

  Future<Map<String, dynamic>> updateMyProfile({
    required String name,
  }) {
    return _client.put(
      ApiConstants.userMe,
      {
        'name': name.trim(),
      },
    );
  }
}
