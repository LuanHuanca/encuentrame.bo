import 'package:flutter/material.dart';

import '../../../../app/router.dart';

/// Pantalla de inicio de sesión.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Login (pendiente de conectar con Cognito)'),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.signup),
                child: const Text('Ir a Registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
