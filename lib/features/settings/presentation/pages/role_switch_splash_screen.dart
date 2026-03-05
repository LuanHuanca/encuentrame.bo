import 'package:flutter/material.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';

class RoleSwitchSplashScreen extends StatefulWidget {
  const RoleSwitchSplashScreen({
    super.key,
    required this.targetRole,
    required this.onRoleChanged,
  });

  final String targetRole;
  final ValueChanged<String> onRoleChanged;

  @override
  State<RoleSwitchSplashScreen> createState() => _RoleSwitchSplashScreenState();
}

class _RoleSwitchSplashScreenState extends State<RoleSwitchSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
    _processSwitch();
  }

  Future<void> _processSwitch() async {
    // Simulamos un delay para que el splash sea notable
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    // Ejecutamos el cambio de rol
    widget.onRoleChanged(widget.targetRole);

    // Regresamos a la pantalla anterior (saliendo del splash screen completo)
    // El MainShell por debajo mostrará la Home correspondiente y cerrará la pantalla de Ajustes.
    
    // Primero cerramos el splash.
    Navigator.of(context).pop();
    
    // Luego verificamos si necesitamos cerrar la página de configuración y perfil 
    // para volver a la raíz de la navegación (el MainShell).
    // popUntil elimina rutas hasta que quede la primera (que es MainShell en la estructura de la app)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    
    final isVendor = widget.targetRole == 'VENDOR';
    final iconData = isVendor ? Icons.storefront_rounded : Icons.shopping_bag_rounded;
    final message = isVendor ? 'Cambiando a Modo Vendedor...' : 'Cambiando a Modo Comprador...';

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
          child: Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.blueNeon.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            size: 72,
                            color: AppColors.blueNeon,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.blueNeon),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
