import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class AuthRepository {
  Future<bool> isSignedIn() async {
    final session = await Amplify.Auth.fetchAuthSession();
    return session.isSignedIn;
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await Amplify.Auth.signUp(
      username: email.trim(),
      password: password,
      options: SignUpOptions(
        userAttributes: {
          AuthUserAttributeKey.email: email.trim(),
        },
      ),
    );
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await Amplify.Auth.confirmSignUp(
      username: email.trim(),
      confirmationCode: code.trim(),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await Amplify.Auth.signIn(
      username: email.trim(),
      password: password,
    );
    if (!res.isSignedIn) {
      throw Exception('Login incompleto: ${res.nextStep.signInStep}');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.google,
      );

      if (!result.isSignedIn) {
        throw Exception(
          'El inicio de sesión con Google no se completó.',
        );
      }
    } catch (e) {
      // Re-lanzar con el mensaje real para diagnóstico
      throw Exception('Google Sign-In falló: $e');
    }
  }

  Future<void> signOut() async {
    await Amplify.Auth.signOut();
  }

  Future<void> startResetPassword({required String email}) async {
    await Amplify.Auth.resetPassword(username: email.trim());
  }

  Future<void> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await Amplify.Auth.confirmResetPassword(
      username: email.trim(),
      newPassword: newPassword,
      confirmationCode: code.trim(),
    );
  }
}