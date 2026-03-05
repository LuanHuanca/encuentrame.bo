import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Barra de búsqueda reutilizable para el modo comprador.
class BuyerSearchBar extends StatelessWidget {
  const BuyerSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Buscar puesto o producto',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: subColor),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
