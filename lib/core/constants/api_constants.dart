/// URLs y endpoints de la API.
class ApiConstants {
  ApiConstants._();

  /// Ruta de health check (GET).
  static const String health = '/api';

  /// Bootstrap de usuario (POST): role (SELLER|BUYER), displayName.
  static const String meBootstrap = '/api/me/bootstrap';
}
