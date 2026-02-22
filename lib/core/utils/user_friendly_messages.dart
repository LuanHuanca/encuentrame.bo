import 'package:flutter/foundation.dart';

import '../../shared/api/rest_client.dart';

/// Convierte errores técnicos (Amplify, API, Exception) en mensajes
/// cortos y amigables para el usuario en español.
/// En UI solo se muestra el mensaje amigable; el detalle va a consola con [logToConsole].
class UserFriendlyMessages {
  UserFriendlyMessages._();

  /// Registra el error completo en consola (solo en debug). En UI usar solo el mensaje amigable.
  static void logToConsole(Object? error, [StackTrace? stackTrace]) {
    if (error == null) return;
    debugPrint('[Encuéntrame] Error: $error');
    if (error is ApiClientException) {
      debugPrint(
        '[Encuéntrame] statusCode=${error.statusCode} code=${error.code} details=${error.details}',
      );
    }
    if (stackTrace != null) {
      debugPrint('[Encuéntrame] $stackTrace');
    }
  }

  /// Mensaje genérico cuando no se reconoce el error.
  static const String genericError = 'Algo salió mal. Intenta de nuevo.';
  static const String noConnection = 'Revisa tu conexión e intenta de nuevo.';

  /// Para errores de autenticación (auth_controller → e.toString()).
  static String fromAuthError(String? raw) {
    if (raw == null || raw.isEmpty) return genericError;
    final lower = raw.toLowerCase();

    // Amplify / Cognito
    if (lower.contains('usernotfoundexception') ||
        lower.contains('user not found')) {
      return 'No encontramos una cuenta con ese correo.';
    }
    if (lower.contains('notauthorizedexception') ||
        lower.contains('incorrect username or password')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('invalidpasswordexception') ||
        lower.contains('password')) {
      return 'La contraseña no cumple los requisitos.';
    }
    if (lower.contains('usernameexists') || lower.contains('already exists')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (lower.contains('code mismatch') ||
        lower.contains('invalid verification')) {
      return 'El código no es correcto. Revisa y vuelve a intentar.';
    }
    if (lower.contains('expired') || lower.contains('código expirado')) {
      return 'El código expiró. Solicita uno nuevo.';
    }
    if (lower.contains('limit exceeded') || lower.contains('too many')) {
      return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('socket')) {
      return noConnection;
    }
    if (lower.contains('signin') || lower.contains('login incompleto')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (lower.contains('already signed in') ||
        lower.contains('invalidstateexception')) {
      return 'Ya tienes una sesión abierta. Serás redirigido.';
    }

    return genericError;
  }

  /// Para errores de API (ApiClientException o mensajes del backend).
  /// Solo devuelve mensajes cortos para la UI; el detalle se registra con [logToConsole].
  static String fromApiError(Object? error) {
    if (error == null) return genericError;
    if (error is ApiClientException) {
      final msg = (error.message).toLowerCase();
      if (msg.contains('unauthorized') || msg.contains('401')) {
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      }
      if (msg.contains('forbidden') || msg.contains('403')) {
        return 'No tienes permiso para hacer esto.';
      }
      if (msg.contains('not found') || msg.contains('404')) {
        return 'No encontramos lo que buscas.';
      }
      if (msg.contains('method not allowed') ||
          msg.contains('método no permitido') ||
          msg.contains('405') ||
          (error.statusCode != null && error.statusCode == 405)) {
        return 'No se pudo guardar tu elección. Intenta de nuevo.';
      }
      if (msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('socket')) {
        return noConnection;
      }
      // Mensaje corto y legible del backend (sin códigos técnicos)
      if (!_looksTechnical(error.message)) return error.message;
    }
    final str = error.toString().toLowerCase();
    if (str.contains('socket') ||
        str.contains('connection') ||
        str.contains('network')) {
      return noConnection;
    }
    return genericError;
  }

  static bool _looksTechnical(String s) {
    final lower = s.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('error:') ||
        lower.contains('status=') ||
        lower.contains('code=') ||
        RegExp(r'^\d{3}\s').hasMatch(s);
  }

  /// Para cualquier Exception/error genérico (ej. role_selection catch (e)).
  static String fromGenericError(Object? error) {
    if (error == null) return genericError;
    if (error is ApiClientException) return fromApiError(error);
    return fromApiError(error.toString());
  }
}
