import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Pantalla para elegir rol SELLER o BUYER (bootstrap).
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige tu rol')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿Cómo quieres usar Encuéntrame?',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  // TODO: llamar POST /api/me/bootstrap con role: SELLER
                  Navigator.pop(context);
                },
                child: Text('Soy vendedor (${AppConstants.roleSeller})'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  // TODO: llamar POST /api/me/bootstrap con role: BUYER
                  Navigator.pop(context);
                },
                child: Text('Soy comprador (${AppConstants.roleBuyer})'),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
