import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class BuyerFilterChip extends StatelessWidget {
  const BuyerFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: icon != null
            ? Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark ? subColor : AppColors.primary),
              )
            : null,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : subColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selectedColor: AppColors.primary,
        backgroundColor: isDark
            ? AppColors.cardOverlayDark
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : titleColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}
