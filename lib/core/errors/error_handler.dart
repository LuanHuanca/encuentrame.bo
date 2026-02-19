import 'app_exception.dart';

/// Manejo centralizado de errores (logging, reportes, mensajes al usuario).
class ErrorHandler {
  ErrorHandler._();

  static void handle(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      // TODO: log o mostrar mensaje según tipo
      return;
    }
    // TODO: log genérico y opcionalmente reportar a servicio externo
  }
}
