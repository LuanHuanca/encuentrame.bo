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

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _redirectIfAlreadySignedIn(),
    );
  }

  Future<void> _redirectIfAlreadySignedIn() async {
    final signedIn = await widget.auth.isSignedIn();
    if (!mounted) return;
    setState(() => _checkingSession = false);
    if (signedIn) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final ok = await widget.auth.signUp(email, password);
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.confirmSignup,
        arguments: {'email': email},
      );
      return;
    }

    AppSnackbar.error(
      context,
      UserFriendlyMessages.fromAuthError(widget.auth.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppThemeColors.backgroundGradient(context),
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
      );
    }

    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
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
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: AutofillGroup(
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
                              style: IconButton.styleFrom(
                                foregroundColor: titleColor,
                              ),
                              tooltip: 'Volver al inicio de sesión',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crear cuenta',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Crea una cuenta y listo. Aquí puedes comprar y vender con la misma sesión.',
                            style: TextStyle(
                              color: AppThemeColors.subtitleColor(context),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          _SignupInputField(
                            controller: _nameController,
                            hint: 'Nombre',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Ingresa tu nombre';
                              if (value.length < 2) return 'Nombre no válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _SignupInputField(
                            controller: _emailController,
                            hint: 'tu@correo.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Ingresa tu correo';
                              if (!value.contains('@')) return 'Correo no válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _SignupInputField(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppThemeColors.inputHint(context),
                                size: 22,
                              ),
                              onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Ingresa una contraseña';
                              if (value.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _SignupInputField(
                            controller: _confirmPasswordController,
                            hint: 'Confirmar contraseña',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppThemeColors.inputHint(context),
                                size: 22,
                              ),
                              onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Confirma tu contraseña';
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 28),
                          _PrimaryButton(
                            onPressed: widget.auth.loading ? null : _submit,
                            label:
                            widget.auth.loading ? 'Cargando...' : 'Registrarse',
                          ),

                          const SizedBox(height: 24),
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
                                onPressed: () =>
                                    Navigator.pushReplacementNamed(context, AppRoutes.login),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Iniciar sesión',
                                  style: TextStyle(
                                    color: AppThemeColors.linkColor(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
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
            ),
          ),

          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(child: ThemeToggleIcon()),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppThemeColors.primaryButtonBg(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.orangeAccent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppThemeColors.primaryButtonFg(context),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupInputField extends StatelessWidget {
  const _SignupInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(color: AppThemeColors.inputText(context), fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppThemeColors.inputHint(context),
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: AppThemeColors.inputHint(context),
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppThemeColors.inputFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orangeAccent),
        ),
      ),
    );
  }
}