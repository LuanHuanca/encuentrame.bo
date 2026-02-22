import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
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
      AppSnackbar.success(
        context,
        'Contraseña actualizada. Ya puedes iniciar sesión.',
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
    } else {
      AppSnackbar.error(
        context,
        UserFriendlyMessages.fromAuthError(widget.auth.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (r) => false,
          ),
          tooltip: 'Volver al inicio de sesión',
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Código enviado a ${widget.email}',
                  style: TextStyle(
                    color: AppThemeColors.subtitleColor(context),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: AppThemeColors.inputText(context),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Código',
                    hintText: 'Ingresa el código',
                    filled: true,
                    fillColor: AppThemeColors.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  style: TextStyle(
                    color: AppThemeColors.inputText(context),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    filled: true,
                    fillColor: AppThemeColors.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppThemeColors.inputHint(context),
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.auth.loading ? null : _confirm,
                    child: Text(
                      widget.auth.loading
                          ? 'Confirmando...'
                          : 'Guardar contraseña',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
