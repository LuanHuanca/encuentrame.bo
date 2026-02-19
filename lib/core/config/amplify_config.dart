import '../../amplifyconfiguration.dart';

/// Carga y expone la configuración de Amplify (Cognito, API, etc.).
/// Por ahora usa el string embebido; luego se puede cambiar por dev/prod.
String get amplifyConfigJson => amplifyconfig;
