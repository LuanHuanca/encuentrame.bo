import 'package:flutter/material.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme_mode_scope.dart';
import '../../../../core/config/app_dependencies.dart';
import 'role_switch_splash_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  final String currentRole;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);
    final themeScope = ThemeModeScope.of(context);
    final themeMode = themeScope?.themeMode ?? ThemeMode.system;
    
    final isVendorRole = currentRole == 'VENDOR';

    // Por ahora tomamos nombre/email básicos desde AuthController si están disponibles.
    final _ = AppDependencies.auth;
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
                
                // Tema de la app
                _buildThemeTile(
                  context: context,
                  themeMode: themeMode,
                  titleColor: titleColor,
                  subColor: subColor,
                  fill: fill,
                  onThemeChanged: (next) {
                    if (next == themeMode) return;
                    if (themeScope?.onToggleTheme == null) return;
                    for (var i = 0; i < 3; i++) {
                      if (ThemeModeScope.of(context)?.themeMode == next) break;
                      themeScope!.onToggleTheme();
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Modo Vendedor/Comprador
                _buildSwitchTile(
                  icon: isVendorRole ? Icons.storefront_rounded : Icons.shopping_bag_rounded,
                  title: 'Modo Vendedor',
                  subtitle: 'Cambiar a herramientas de venta',
                  value: isVendorRole,
                  onChanged: (val) {
                    final targetRole = val ? 'VENDOR' : 'BUYER';
                    if (currentRole == targetRole) return;
                    
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                            RoleSwitchSplashScreen(
                              targetRole: targetRole,
                              onRoleChanged: onRoleChanged,
                            ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  titleColor: titleColor,
                  subColor: subColor,
                  fill: fill,
                ),
                const SizedBox(height: 12),

                // Notificaciones
                _buildSwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Notificaciones',
                  subtitle: 'Recibir alertas y mensajes',
                  value: true,
                  onChanged: (val) {}, // Placeholder
                  titleColor: titleColor,
                  subColor: subColor,
                  fill: fill,
                ),
                const SizedBox(height: 12),

                // Ubicación
                _buildSwitchTile(
                  icon: Icons.location_on_rounded,
                  title: 'Ubicación',
                  subtitle: 'Permitir acceso a la ubicación',
                  value: false,
                  onChanged: (val) {}, // Placeholder
                  titleColor: titleColor,
                  subColor: subColor,
                  fill: fill,
                ),
                const SizedBox(height: 12),

                // Idioma
                _buildDropdownTile<String>(
                  icon: Icons.language_rounded,
                  title: 'Idioma',
                  subtitle: 'Selecciona tu idioma preferido',
                  value: 'es',
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('Inglés')),
                  ],
                  onChanged: (val) {}, // Placeholder
                  titleColor: titleColor,
                  subColor: subColor,
                  fill: fill,
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
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required ThemeMode themeMode,
    required Color titleColor,
    required Color subColor,
    required Color fill,
    required void Function(ThemeMode) onThemeChanged,
  }) {
    IconData icon;
    if (themeMode == ThemeMode.dark) {
      icon = Icons.dark_mode_rounded;
    } else if (themeMode == ThemeMode.light) {
      icon = Icons.light_mode_rounded;
    } else {
      icon = Icons.brightness_6_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blueNeon),
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
          const SizedBox(width: 16),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: themeMode,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: fill,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              onChanged: (ThemeMode? next) {
                if (next != null) {
                  onThemeChanged(next);
                }
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Sistema'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color titleColor,
    required Color subColor,
    required Color fill,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blueNeon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.blueNeon,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color titleColor,
    required Color subColor,
    required Color fill,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blueNeon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: fill,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              onChanged: onChanged,
              items: items,
            ),
          ),
        ],
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
