import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Pantalla de carga inicial con animación (persona comprando).
/// Modular: sin dependencias de red; solo animaciones locales.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _cartController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _cartAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _cartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _cartAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? [AppColors.blueSurface, AppColors.backgroundDark, AppColors.blueDark]
        : [AppColors.blueLightBg, Colors.white, const Color(0xFFBBDEFB)];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _cartController,
                ]),
                builder: (context, _) {
                  return _SplashIllustration(
                    pulseScale: _pulseAnim.value,
                    cartValue: _cartAnim.value,
                  );
                },
              ),
              const Spacer(flex: 1),
              Text(
                'Encuéntrame',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppThemeColors.titleColor(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Encuentra lo que buscas',
                style: TextStyle(
                  color: AppThemeColors.subtitleColor(context),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.orangeBright,
                  backgroundColor: AppColors.blueNeon.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ilustración animada: persona con bolsa de compras.
class _SplashIllustration extends StatelessWidget {
  const _SplashIllustration({
    required this.pulseScale,
    required this.cartValue,
  });

  final double pulseScale;
  final double cartValue;

  @override
  Widget build(BuildContext context) {
    // Movimiento suave del carrito/bolsa (oscilación lateral)
    final swing = math.sin(cartValue * math.pi * 2) * 6.0;

    return Transform.scale(
      scale: pulseScale,
      child: SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Persona (icono central)
            Icon(
              Icons.person_rounded,
              size: 100,
              color: AppColors.blueNeon.withValues(alpha: 0.9),
            ),
            // Bolsa de compras que “flota” al lado
            Positioned(
              right: 24 + swing,
              bottom: 20,
              child: Transform.rotate(
                angle: -0.1 + (swing * 0.008),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  size: 56,
                  color: AppColors.orangeBright,
                ),
              ),
            ),
            // Pequeño ícono de “check” o producto
            Positioned(
              left: 28 + swing * 0.5,
              top: 32,
              child: Icon(
                Icons.storefront_rounded,
                size: 40,
                color: AppColors.bluePrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
