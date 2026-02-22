import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppThemeColors.titleColor(context),
                    ),
                    tooltip: 'Volver',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recuperar contraseña',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppThemeColors.titleColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Te enviaremos un código a tu correo para restablecer tu contraseña.',
                  style: TextStyle(
                    color: AppThemeColors.subtitleColor(context),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: AppThemeColors.inputText(context),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@correo.com',
                    filled: true,
                    fillColor: AppThemeColors.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.auth.loading ? null : _send,
                    child: Text(
                      widget.auth.loading ? 'Enviando...' : 'Enviar código',
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
