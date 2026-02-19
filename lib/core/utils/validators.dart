/// Validadores reutilizables para formularios.
class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'El correo es obligatorio';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Correo no válido';
    return null;
  }

  static String? required(String? value, [String fieldName = 'Este campo']) {
    if (value == null || value.trim().isEmpty)
      return '$fieldName es obligatorio';
    return null;
  }

  static String? minLength(
    String? value,
    int min, [
    String fieldName = 'Este campo',
  ]) {
    if (value == null) return null;
    if (value.length < min)
      return '$fieldName debe tener al menos $min caracteres';
    return null;
  }
}
