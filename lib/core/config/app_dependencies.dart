import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_controller.dart';

class AppDependencies {
  AppDependencies._();

  static final auth = AuthController(AuthRepository());
}