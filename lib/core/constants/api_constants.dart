class ApiConstants {
  ApiConstants._();

  static const String health = '/health';

  static const String stalls = '/stalls';
  static const String stallsOpen = '/stalls/open';
  static const String userMe = '/users/me';

  static const String marketOpenStalls = '/market/open-stalls';
  static const String marketSearchProducts = '/market/products/search';
  static const String marketCategories = '/market/categories';

  static String stallById(String stallId) => '/stalls/$stallId';
  static String stallClose(String stallId) => '/stalls/$stallId/close';
  static String stallCurrent(String stallId) => '/stalls/$stallId/current';
  static String stallProducts(String stallId) => '/stalls/$stallId/products';
  static String stallProductById(String stallId, String productId) =>
      '/stalls/$stallId/products/$productId';

  static String marketStallDetail(String stallId) => '/market/stalls/$stallId';
}