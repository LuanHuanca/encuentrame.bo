import 'package:flutter/material.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme_mode_scope.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final String currentMode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);
    final themeScope = ThemeModeScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Preferencias',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                color: fillColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elige cómo quieres ver la aplicación.',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ThemeMode>(
                      value: themeScope?.themeMode ?? ThemeMode.system,
                      decoration: const InputDecoration(
                        labelText: 'Modo de tema',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Claro'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Oscuro'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Sistema'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null || themeScope == null) return;
                        themeScope.onSetThemeMode(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                color: fillColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo actual',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentMode == MainShellMode.vendor
                          ? 'Estás usando la app como vendedor.'
                          : 'Estás usando la app como comprador.',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final nextMode =
                          currentMode == MainShellMode.vendor
                              ? MainShellMode.buyer
                              : MainShellMode.vendor;

                          onModeChanged(nextMode);
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          currentMode == MainShellMode.vendor
                              ? Icons.search_rounded
                              : Icons.storefront_rounded,
                        ),
                        label: Text(
                          currentMode == MainShellMode.vendor
                              ? 'Cambiar a comprador'
                              : 'Cambiar a vendedor',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    required this.color,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}