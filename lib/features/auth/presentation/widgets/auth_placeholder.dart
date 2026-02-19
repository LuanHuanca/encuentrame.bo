import 'package:flutter/material.dart';

/// Widget placeholder para la feature auth (ej. botón con estilo de auth).
class AuthPlaceholder extends StatelessWidget {
  const AuthPlaceholder({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
