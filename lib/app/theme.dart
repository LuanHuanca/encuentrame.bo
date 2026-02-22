import 'package:flutter/material.dart';

/// Colores de la marca Encuéntrame (teal/verde azulado + naranja).
/// Usar [AppThemeColors] en pantallas para respetar modo claro/oscuro.
class AppColors {
  AppColors._();

  /// Primario: teal que combina con naranja (menos azul puro).
  static const Color primary = Color(0xFF00796B);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color primaryLight = Color(0xFF4DB6AC);

  /// Compatibilidad con código que usa nombres antiguos.
  static const Color bluePrimary = Color(0xFF00796B);
  static const Color blueDark = Color(0xFF004D40);
  static const Color blueSurface = Color(0xFF1A2525);
  static const Color blueNeon = Color(0xFF4DB6AC);
  static const Color blueLightBg = Color(0xFFE0F2F1);

  static const Color orangeAccent = Color(0xFFE65100);
  static const Color orangeBright = Color(0xFFFF9800);
  static const Color orangeSoft = Color(0xFFFFB74D);

  static const Color backgroundDark = Color(0xFF121A1C);
  static const Color cardOverlayDark = Color(0x1AFFFFFF);

  /// Fondo de campos en modo claro (tono neutro cálido).
  static const Color cardOverlayLight = Color(0xFFF5F5F5);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textMutedDark = Color(0xB3FFFFFF);
  static const Color textOnLight = Color(0xFF1A1A1A);
  static const Color textMutedLight = Color(0xFF616161);

  /// Fondos claros para gradientes (menos azul, más neutro/teal suave).
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceLightEnd = Color(0xFFE8F5F4);

  /// Estado: abierto (activo) y cerrado.
  static const Color statusOpen = Color(0xFF2E7D32);
  static const Color statusClosed = Color(0xFF616161);
}

/// Colores según tema actual (claro/oscuro) para buena legibilidad.
class AppThemeColors {
  AppThemeColors._();

  static Color titleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textOnDark
        : AppColors.textOnLight;
  }

  static Color subtitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;
  }

  static Color inputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.cardOverlayDark
        : AppColors.cardOverlayLight;
  }

  static Color inputText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textOnDark
        : AppColors.textOnLight;
  }

  static Color inputHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;
  }

  static List<Color> backgroundGradient(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return [
        AppColors.blueSurface,
        AppColors.backgroundDark,
        AppColors.primaryDark,
      ];
    }
    return [AppColors.blueLightBg, Colors.white, AppColors.surfaceLightEnd];
  }

  static Color linkColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  static Color primaryButtonBg(BuildContext context) {
    return AppColors.orangeAccent;
  }

  static Color primaryButtonFg(BuildContext context) {
    return Colors.white;
  }
}

/// Tema global de la aplicación Encuéntrame.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.orangeBright,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textOnLight,
        onSurfaceVariant: AppColors.textMutedLight,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orangeAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.orangeBright,
        surface: AppColors.blueSurface,
        onPrimary: Colors.black87,
        onSecondary: Colors.black87,
        onSurface: AppColors.textOnDark,
        onSurfaceVariant: AppColors.textMutedDark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orangeAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
      ),
    );
  }
}
