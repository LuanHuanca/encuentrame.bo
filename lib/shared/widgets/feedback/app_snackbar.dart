import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Muestra feedback al usuario con SnackBars consistentes con la app.
/// Usar en lugar de ScaffoldMessenger.showSnackBar con texto crudo.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    final backgroundColor = isError
        ? AppColors.orangeAccent
        : isSuccess
        ? const Color(0xFF2E7D32) // verde suave
        : theme.colorScheme.inverseSurface;
    final foregroundColor = isError || isSuccess
        ? Colors.white
        : theme.colorScheme.onInverseSurface;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : (isSuccess
                        ? Icons.check_circle_outline
                        : Icons.info_outline),
              color: foregroundColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: foregroundColor, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, isSuccess: true);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message);
  }
}
