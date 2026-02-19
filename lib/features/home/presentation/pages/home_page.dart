import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';

/// Pantalla principal. Muestra un widget de ejemplo y navegación.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido a ${AppConstants.appName}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Widget de ejemplo: botón primario reutilizable.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Ver perfil',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.profile),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Elegir rol (SELLER/BUYER)',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.roleSelection),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Puestos',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.stalls),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
