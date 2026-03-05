import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/theme_mode_scope.dart';
import '../../../../core/config/app_dependencies.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);
    final themeScope = ThemeModeScope.of(context);
    final themeMode = themeScope?.themeMode ?? ThemeMode.system;

    // Por ahora tomamos nombre/email básicos desde AuthController si están disponibles.
    final _ = AppDependencies.auth;
    // Por ahora no tenemos getters dedicados en AuthController; usamos placeholders.
    const email = '';
    const displayName = '';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Preferencias',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : themeMode == ThemeMode.light
                            ? Icons.light_mode_rounded
                            : Icons.brightness_6_rounded,
                        color: AppColors.blueNeon,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tema de la app',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _themeLabel(themeMode),
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Claro'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Oscuro'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Sistema'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (values) {
                          final next = values.first;
                          if (next == themeMode) return;
                          if (themeScope?.onToggleTheme == null) return;

                          // ThemeModeScope solo expone toggle; llamamos hasta llegar al valor.
                          // Para evitar loops, limitamos a 3 pasos.
                          for (var i = 0; i < 3; i++) {
                            if (ThemeModeScope.of(context)?.themeMode == next) {
                              break;
                            }
                            themeScope!.onToggleTheme();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Información de la cuenta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Nombre',
                        value: displayName.isNotEmpty
                            ? displayName
                            : 'Sin nombre configurado',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Correo',
                        value: email.isNotEmpty
                            ? email
                            : 'Correo no disponible',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Según el sistema';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: subColor, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
