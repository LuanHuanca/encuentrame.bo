import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Contenedor con gradiente de fondo para pantallas del modo comprador.
class BuyerScaffoldGradient extends StatelessWidget {
  const BuyerScaffoldGradient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppThemeColors.backgroundGradient(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
