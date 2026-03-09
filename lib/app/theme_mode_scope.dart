import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kThemeModeKey = 'theme_mode';

class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required super.child,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final ValueChanged<ThemeMode> onSetThemeMode;

  static ThemeModeScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
  }

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

class ThemeModeStorage {
  ThemeModeStorage._();

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(kThemeModeKey);

      if (index != null && index >= 0 && index < ThemeMode.values.length) {
        return ThemeMode.values[index];
      }
    } catch (_) {}

    return ThemeMode.system;
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kThemeModeKey, mode.index);
    } catch (_) {}
  }
}