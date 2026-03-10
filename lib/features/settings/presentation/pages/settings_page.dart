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

  bool get _isVendorMode => currentMode == MainShellMode.vendor;

  String _modeTitle() {
    return _isVendorMode ? 'Modo vendedor' : 'Modo comprador';
  }

  String _modeDescription() {
    return _isVendorMode
        ? 'Gestiona tu puesto, inventario, productos y publicaciones activas.'
        : 'Explora productos cercanos, encuentra puestos y revisa ubicaciones.';
  }

  String _modeButtonLabel() {
    return _isVendorMode ? 'Cambiar a comprador' : 'Cambiar a vendedor';
  }

  IconData _modeButtonIcon() {
    return _isVendorMode
        ? Icons.search_rounded
        : Icons.storefront_rounded;
  }

  IconData _modeHeroIcon() {
    return _isVendorMode
        ? Icons.storefront_rounded
        : Icons.shopping_bag_rounded;
  }

  String _modeHelperText() {
    return 'Tu cuenta es la misma. Solo cambias la forma de usar la app.';
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);
    final themeScope = ThemeModeScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
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
              const SizedBox(height: 8),
              Text(
                'Personaliza cómo ves y usas Encuéntrame.',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              _HeroModeCard(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                icon: _modeHeroIcon(),
                title: _modeTitle(),
                description: _modeDescription(),
                helperText: _modeHelperText(),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                color: fillColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.palette_outlined,
                      title: 'Tema',
                      subtitle: 'Elige cómo quieres ver la aplicación.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ThemeMode>(
                      value: themeScope?.themeMode ?? ThemeMode.system,
                      decoration: const InputDecoration(
                        labelText: 'Modo de tema',
                      ),
                      borderRadius: BorderRadius.circular(16),
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
                    _SectionHeader(
                      icon: _isVendorMode
                          ? Icons.storefront_outlined
                          : Icons.travel_explore_rounded,
                      title: 'Modo de uso',
                      subtitle: _modeHelperText(),
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 14),
                    _CurrentModePill(
                      isVendorMode: _isVendorMode,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _modeDescription(),
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final nextMode = _isVendorMode
                              ? MainShellMode.buyer
                              : MainShellMode.vendor;

                          onModeChanged(nextMode);
                          Navigator.pop(context);
                        },
                        icon: Icon(_modeButtonIcon()),
                        label: Text(_modeButtonLabel()),
                      ),
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
                    _SectionHeader(
                      icon: Icons.info_outline_rounded,
                      title: 'Sobre esta configuración',
                      subtitle: 'Lo importante, sin vueltas.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                      'Cambiar de modo no cambia tu cuenta ni tu sesión.',
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                      'Solo cambia qué herramientas ves primero dentro de la app.',
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                      'Puedes cambiar entre comprador y vendedor cuando quieras.',
                      subtitleColor: subtitleColor,
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

class _HeroModeCard extends StatelessWidget {
  const _HeroModeCard({
    required this.titleColor,
    required this.subtitleColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.helperText,
  });

  final Color titleColor;
  final Color subtitleColor;
  final IconData icon;
  final String title;
  final String description;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.blueNeon.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    helperText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.blueNeon,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentModePill extends StatelessWidget {
  const _CurrentModePill({
    required this.isVendorMode,
  });

  final bool isVendorMode;

  @override
  Widget build(BuildContext context) {
    final bgColor = isVendorMode
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.orangeBright.withValues(alpha: 0.14);

    final borderColor = isVendorMode
        ? AppColors.primary.withValues(alpha: 0.28)
        : AppColors.orangeBright.withValues(alpha: 0.30);

    final iconColor =
    isVendorMode ? AppColors.primary : AppColors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVendorMode
                ? Icons.storefront_rounded
                : Icons.search_rounded,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Text(
            isVendorMode ? 'Ahora mismo: vendedor' : 'Ahora mismo: comprador',
            style: TextStyle(
              color: iconColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.subtitleColor,
  });

  final IconData icon;
  final String text;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.statusOpen,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}