import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave para guardar preferencia de tema.
const String _kThemeModeKey = 'theme_mode';

/// Proporciona el tema actual y la acción para alternar entre claro/oscuro.
class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required super.child,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  static ThemeModeScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
  }

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

/// Carga y guarda la preferencia de tema.
class ThemeModeStorage {
  ThemeModeStorage._();

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_kThemeModeKey);
      if (index != null && index >= 0 && index <= 2) {
        return ThemeMode.values[index];
      }
    } catch (_) {}
    return ThemeMode.system;
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kThemeModeKey, mode.index);
    } catch (_) {}
  }
}
