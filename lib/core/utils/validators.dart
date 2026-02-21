class Validators {
  Validators._();

  static String? requiredText(String? v, {String message = 'Campo requerido'}) {
    if (v == null || v.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? email(String? v, {String message = 'Correo no válido'}) {
    if (v == null || v.trim().isEmpty) {
      return 'Ingresa tu correo';
    }
    if (!v.contains('@')) {
      return message;
    }
    return null;
  }

  static String? minLength(String? v, int min, {String? message}) {
    if (v == null || v.isEmpty) {
      return 'Campo requerido';
    }
    if (v.length < min) {
      return message ?? 'Mínimo $min caracteres';
    }
    return null;
  }
}