class ApiConstants {
  ApiConstants._();

  /// Amplify REST API name.
  static const String restApiName = 'apic45634fb';

  /// Backend base path.
  static const String basePath = '/api';

  /// General
  static const String health = '/health';
  static const String me = '/users/me';

  /// Buyer / market
  static const String marketOpenStalls = '/market/open-stalls';
  static const String marketSearchProducts = '/market/products/search';

  static String marketStallProducts(String stallId) {
    return '/market/stalls/$stallId/products';
  }

  /// Vendor / stalls
  static const String stalls = '/stalls';
  static const String openStall = '/stalls/open';

  static String stallById(String stallId) => '/stalls/$stallId';

  static String stallCurrent(String stallId) => '/stalls/$stallId/current';

  static String stallClose(String stallId) => '/stalls/$stallId/close';

  static String stallProducts(String stallId) => '/stalls/$stallId/products';

  static String stallProductById(String stallId, String productId) {
    return '/stalls/$stallId/products/$productId';
  }
}