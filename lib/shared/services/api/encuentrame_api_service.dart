// TODO: Servicio que llama (usar ApiConstants.health, ApiConstants.meBootstrap) a la API (health, POST /api/me/bootstrap, etc.)
// usando el api_client o Amplify.API con la config de amplify_config.

/// Servicio para la API Encuéntrame.
class EncuentrameApiService {
  Future<Map<String, dynamic>?> health() async {
    // GET ApiConstants.health
    return null;
  }

  Future<Map<String, dynamic>?> bootstrapMe({
    required String role,
    String displayName = '',
  }) async {
    // POST ApiConstants.meBootstrap { role, displayName }
    return null;
  }
}
