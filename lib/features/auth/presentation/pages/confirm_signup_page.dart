import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final AuthController auth;
  final String email;

  @override
  State<ConfirmSignupPage> createState() => _ConfirmSignupPageState();
}

class _ConfirmSignupPageState extends State<ConfirmSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await widget.auth.confirmSignUp(
      widget.email.trim(),
      _codeController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      AppSnackbar.success(
        context,
        'Cuenta confirmada. Ya puedes iniciar sesión.',
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
      return;
    }

    AppSnackbar.error(
      context,
      UserFriendlyMessages.fromAuthError(widget.auth.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
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
                      style:
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                    const SizedBox(height: 8),
                    Text(
                      'Revisa también tu bandeja de spam si no lo encuentras.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppThemeColors.subtitleColor(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onFieldSubmitted: (_) => _confirm(),
                      style: TextStyle(color: AppThemeColors.inputText(context)),
                      decoration: InputDecoration(
                        hintText: 'Código de verificación',
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
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Ingresa el código';
                        if (value.length < 4) return 'Código no válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: widget.auth.loading ? null : _confirm,
                        child: Text(
                          widget.auth.loading ? 'Confirmando...' : 'Confirmar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}