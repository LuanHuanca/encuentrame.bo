import 'package:flutter/material.dart';

import 'theme_mode_scope.dart';

/// Icono compacto para alternar entre tema claro y oscuro.
/// Muestra luna en modo claro y sol en modo oscuro.
class ThemeToggleIcon extends StatelessWidget {
  const ThemeToggleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ThemeModeScope.of(context);
    if (scope == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: scope.onToggleTheme,
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
    );
  }
}
