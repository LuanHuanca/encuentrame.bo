import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Título de sección reutilizable para listados del comprador.
class BuyerSectionHeader extends StatelessWidget {
  const BuyerSectionHeader({
    super.key,
    required this.title,
    this.fontSize = 16,
  });

  final String title;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);

    return Text(
      title,
      style: TextStyle(
        color: titleColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
