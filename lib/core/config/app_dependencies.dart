import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../shared/services/api/encuentrame_api_service.dart';

class AppDependencies {
  AppDependencies._();

  static final auth = AuthController(AuthRepository());

  /// Servicio de alto nivel para la API Encuéntrame (buyer, bootstrap, etc.).
  static final api = EncuentrameApiService();
}
