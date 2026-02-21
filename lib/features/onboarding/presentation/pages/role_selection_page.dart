import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../shared/api/rest_client.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final api = RestClient();
  bool loading = false;

  Future<void> _setRole(String role) async {
    setState(() => loading = true);
    try {
      await api.put('/users/me', {'role': role});
      if (!mounted) return;

      if (role == 'VENDOR') {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.stalls, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando rol: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige tu rol')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Esto se guarda en DynamoDB (users-dev).'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : () => _setRole('VENDOR'),
                child: Text(loading ? 'Guardando...' : 'Soy Vendedor'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : () => _setRole('BUYER'),
                child: Text(loading ? 'Guardando...' : 'Soy Comprador'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}