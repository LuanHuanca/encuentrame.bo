class ApiConstants {
  ApiConstants._();

  /// Nombre de la API REST configurada en Amplify.
  static const String restApiName = 'apic45634fb';

  /// Prefijo base de la API (por el swagger /api).
  static const String basePath = '/api';

  /// Endpoints generales
  static const String health = '/health';

  /// Usuario / bootstrap
  static const String me = '/users/me';
  static const String meBootstrap = '/me/bootstrap';

  /// Endpoints de mercado (buyer)
  static const String marketOpenStalls = '/market/open-stalls';
  static const String marketOrders = '/market/orders';
  static const String marketSearchProducts = '/market/products/search';

  static String marketStallProducts(String stallId) =>
      '/market/stalls/$stallId/products';
}
