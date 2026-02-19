// TODO: Wrapper de Amplify Auth (signIn, signUp, signOut, currentUser, etc.)
// Inicializar Amplify en main.dart con core/config/amplify_config.dart

/// Servicio de autenticación (Cognito vía Amplify).
class AuthService {
  Future<bool> get isSignedIn async => false;

  Future<void> signOut() async {}
}
