import 'package:flutter/material.dart';

/// Colores de la marca Encuéntrame (azul y naranja).
/// Usar [AppThemeColors] en pantallas para respetar modo claro/oscuro.
class AppColors {
  AppColors._();

  static const Color bluePrimary = Color(0xFF1565C0);
  static const Color blueDark = Color(0xFF0D47A1);
  static const Color blueSurface = Color(0xFF1C2836);
  static const Color blueNeon = Color(0xFF42A5F5);
  static const Color blueLightBg = Color(0xFFE3F2FD);

  static const Color orangeAccent = Color(0xFFE65100);
  static const Color orangeBright = Color(0xFFFF9800);
  static const Color orangeSoft = Color(0xFFFFB74D);

  static const Color backgroundDark = Color(0xFF121A24);
  static const Color cardOverlayDark = Color(0x1AFFFFFF);

  /// Fondo de campos en modo claro (legible sobre fondo claro).
  static const Color cardOverlayLight = Color(0xFFF0F4F8);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textMutedDark = Color(0xB3FFFFFF);
  static const Color textOnLight = Color(0xFF1A1A1A);
  static const Color textMutedLight = Color(0xFF616161);
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
        AppColors.blueDark,
      ];
    }
    return [AppColors.blueLightBg, Colors.white, const Color(0xFFBBDEFB)];
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
        primary: AppColors.bluePrimary,
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
        primary: AppColors.blueNeon,
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
