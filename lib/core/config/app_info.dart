class AppInfo {
  AppInfo._();

  static const String appName = 'Encuéntrame';

  /// Cambiable con:
  /// flutter run --dart-define=APP_VERSION=0.1
  /// flutter build apk --dart-define=APP_VERSION=0.1
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1',
  );

  static String get versionLabel => 'Versión $appVersion';
}