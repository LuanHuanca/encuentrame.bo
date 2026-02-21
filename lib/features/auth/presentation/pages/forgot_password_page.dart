import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../auth_controller.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_email.text.trim().isEmpty) return;

    final ok = await widget.auth.startResetPassword(_email.text.trim());

    if (!mounted) return;

    if (ok) {
      Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: {'email': _email.text.trim()},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.auth.error ?? 'Error enviando código')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.auth.loading ? null : _send,
                child: Text(widget.auth.loading ? 'Enviando...' : 'Enviar código'),
              ),
            ),
            if (widget.auth.error != null) ...[
              const SizedBox(height: 12),
              Text(widget.auth.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}