import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/app_dependencies.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../purchases/presentation/pages/my_purchases_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

/// Pantalla de perfil de usuario.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  bool _switchLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await AppDependencies.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Scaffold(
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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Mi perfil',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: fill,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blueNeon.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: AppColors.blueNeon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  // Switch de vista vendedor/comprador
                  Builder(
                    builder: (context) {
                      final role = MainShell.of(context)?.role ?? 'BUYER';
                      final isVendorView = role == 'VENDOR';
                      final title = isVendorView
                          ? 'Viendo como vendedor'
                          : 'Viendo como comprador';
                      final subtitle = isVendorView
                          ? 'Activa el switch para ver la app como comprador.'
                          : 'Activa el switch para ver la app como vendedor.';

                      return Opacity(
                        opacity: _switchLoading ? 0.6 : 1,
                        child: IgnorePointer(
                          ignoring: _switchLoading,
                          child: Container(
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
                                  Icons.swap_horiz_rounded,
                                  color: AppColors.blueNeon,
                                  size: 26,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: isVendorView,
                                  activeColor: AppColors.blueNeon,
                                  onChanged: (value) async {
                                    final shell = MainShell.of(context);
                                    if (shell == null) return;

                                    setState(() => _switchLoading = true);

                                    // Pantalla de carga modal para resaltar el cambio
                                    showDialog<void>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) {
                                        return Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Theme.of(ctx)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: 0.92),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 40,
                                                  height: 40,
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  value
                                                      ? 'Cambiando a vista vendedor...'
                                                      : 'Cambiando a vista comprador...',
                                                  style: TextStyle(
                                                    color:
                                                        AppThemeColors.titleColor(
                                                          ctx,
                                                        ),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    await Future.delayed(
                                      const Duration(milliseconds: 600),
                                    );

                                    if (!mounted) return;

                                    if (value) {
                                      shell.setRole('VENDOR');
                                    } else {
                                      shell.setRole('BUYER');
                                    }

                                    if (mounted) {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop();
                                      setState(() => _switchLoading = false);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ProfileTile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Mis compras',
                    subtitle: 'Historial de compras',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyPurchasesPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileTile(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Favoritos',
                    subtitle: 'Puestos y productos guardados',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileTile(
                    icon: Icons.settings_outlined,
                    title: 'Ajustes',
                    subtitle: 'Tema y preferencias',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded, size: 22),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orangeAccent,
                        side: const BorderSide(color: AppColors.orangeAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.blueNeon, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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
              Icon(Icons.chevron_right_rounded, color: subColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
