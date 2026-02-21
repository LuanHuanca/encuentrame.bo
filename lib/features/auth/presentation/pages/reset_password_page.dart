import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../auth_controller.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth, required this.email});
  final AuthController auth;
  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.trim().isEmpty || _pass.text.isEmpty) return;

    final ok = await widget.auth.confirmResetPassword(
      widget.email,
      _code.text.trim(),
      _pass.text,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada ✅')),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.auth.error ?? 'Error al cambiar contraseña')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Email: ${widget.email}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Código'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.auth.loading ? null : _confirm,
                child: Text(widget.auth.loading ? 'Confirmando...' : 'Confirmar'),
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