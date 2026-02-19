import 'package:flutter/material.dart';

/// Tema global de la aplicación Encuéntrame.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }
}
