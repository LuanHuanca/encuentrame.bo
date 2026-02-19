/// Excepción base para errores de la aplicación.
class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (code: $code)' : ''}';
}
