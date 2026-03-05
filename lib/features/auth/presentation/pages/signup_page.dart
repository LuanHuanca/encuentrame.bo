import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme_toggle_icon.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../auth_controller.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await widget.auth.signUp(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.confirmSignup,
        arguments: {'email': _emailController.text.trim()},
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
    final titleColor = AppThemeColors.titleColor(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                child: Form(
                  key: _formKey,
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
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(foregroundColor: titleColor),
                          tooltip: 'Volver',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crear cuenta',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Una cuenta para comprar y vender.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppThemeColors.subtitleColor(context)),
                      ),
                      const SizedBox(height: 28),

                      _InputField(
                        controller: _emailController,
                        hint: 'tu@correo.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Ingresa tu correo';
                          if (!value.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _InputField(
                        controller: _passwordController,
                        hint: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppThemeColors.inputHint(context),
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return 'Ingresa una contraseña';
                          if (value.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _InputField(
                        controller: _confirmPasswordController,
                        hint: 'Confirmar contraseña',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppThemeColors.inputHint(context),
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return 'Confirma tu contraseña';
                          if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: widget.auth.loading ? null : _submit,
                          child: Text(widget.auth.loading ? 'Creando...' : 'Crear cuenta'),
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿Ya tienes cuenta? ',
                            style: TextStyle(
                              color: AppThemeColors.subtitleColor(context),
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                            child: Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: AppThemeColors.linkColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(top: 0, right: 0, child: SafeArea(child: ThemeToggleIcon())),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppThemeColors.inputText(context), fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppThemeColors.inputHint(context), size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppThemeColors.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}