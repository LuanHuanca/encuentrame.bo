import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../auth_controller.dart';

class ConfirmSignupPage extends StatefulWidget {
  const ConfirmSignupPage({
    super.key,
    required this.auth,
    required this.email,
    required this.pendingRole,
    required this.pendingName,
  });

  final AuthController auth;
  final String email;

  // Siguiente fase: se guardarán en DynamoDB vía /users/me
  final String pendingRole;
  final String pendingName;

  @override
  State<ConfirmSignupPage> createState() => _ConfirmSignupPageState();
}

class _ConfirmSignupPageState extends State<ConfirmSignupPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.trim().isEmpty) return;

    final ok = await widget.auth.confirmSignUp(widget.email, _code.text.trim());

    if (!mounted) return;

    if (ok) {
      AppSnackbar.success(
        context,
        'Cuenta confirmada. Ya puedes iniciar sesión.',
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (r) => false,
                    ),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppThemeColors.titleColor(context),
                    ),
                    tooltip: 'Volver al inicio de sesión',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirmar cuenta',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppThemeColors.titleColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Código enviado a:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppThemeColors.subtitleColor(context),
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppThemeColors.inputText(context)),
                  decoration: InputDecoration(
                    hintText: 'Código',
                    hintStyle: TextStyle(
                      color: AppThemeColors.inputHint(context),
                    ),
                    filled: true,
                    fillColor: AppThemeColors.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.auth.loading ? null : _confirm,
                  child: Text(
                    widget.auth.loading ? 'Confirmando...' : 'Confirmar',
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
