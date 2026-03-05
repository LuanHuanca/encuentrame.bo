import '../../../core/constants/api_constants.dart';
import '../../api/rest_client.dart';

/// Servicio de alto nivel para la API Encuéntrame.
///
/// Envuelve a [RestClient] y expone métodos tipados para los endpoints
/// principales (health, bootstrap y flujo de mercado/buyer).
class EncuentrameApiService {
  EncuentrameApiService({RestClient? client})
    : _client = client ?? RestClient();

  final RestClient _client;

  /// Verifica el estado de la API.
  Future<Map<String, dynamic>> health() {
    return _client.get(ApiConstants.health);
  }

  /// Inicializa el usuario en la API (buyer o seller) y devuelve el payload.
  Future<Map<String, dynamic>?> bootstrapMe({
    required String role,
    String displayName = '',
  }) async {
    final body = <String, dynamic>{
      'role': role,
      if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
    };
    return _client.post(ApiConstants.meBootstrap, body);
  }

  /// Lista puestos abiertos cerca de la posición del usuario.
  ///
  /// Devuelve la respuesta cruda del backend para que la UI decida cómo
  /// mapearla.
  Future<Map<String, dynamic>> listOpenStallsNear({
    required double lat,
    required double lng,
    double radiusKm = 2,
    int limit = 30,
    String? query,
    bool includeProducts = false,
    int productsLimit = 6,
  }) {
    final qp = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
      'includeProducts': includeProducts ? '1' : '0',
      'productsLimit': productsLimit.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }
    return _client.get(ApiConstants.marketOpenStalls, queryParameters: qp);
  }

  /// Lista productos públicos de un puesto para el flujo de comprador.
  Future<Map<String, dynamic>> listStallProductsPublic({
    required String stallId,
    String? query,
    int limit = 50,
  }) {
    final qp = <String, String>{'limit': limit.toString()};
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }

    return _client.get(
      ApiConstants.marketStallProducts(stallId),
      queryParameters: qp,
    );
  }

  /// Busca productos cerca del usuario por texto libre.
  Future<Map<String, dynamic>> searchProductsNear({
    required double lat,
    required double lng,
    required String query,
    double radiusKm = 2,
    int limit = 30,
  }) {
    final qp = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'q': query.trim(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
    };

    return _client.get(ApiConstants.marketSearchProducts, queryParameters: qp);
  }

  /// Crea una orden de compra para un puesto.
  ///
  /// [items] debe ser una lista de mapas con al menos:
  /// `{ productId: string, qty: number }`.
  Future<Map<String, dynamic>> createOrder({
    required String stallId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) {
    final body = <String, dynamic>{
      'stallId': stallId,
      'items': items,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    return _client.post(ApiConstants.marketOrders, body);
  }
}
