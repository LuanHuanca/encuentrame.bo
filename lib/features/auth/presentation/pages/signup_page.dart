import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme_toggle_icon.dart';
import '../auth_controller.dart';

/// Rol seleccionado en el registro (mapear a VENDOR/BUYER).
enum SignupRole { vendedor, comprador }

/// Pantalla de registro con selección de rol (vendedor/comprador).
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
  SignupRole? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige si eres vendedor o comprador')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await widget.auth.signUp(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.confirmSignup,
        arguments: {
          'email': _emailController.text.trim(),
          'role': _selectedRole == SignupRole.vendedor ? 'VENDOR' : 'BUYER',
          'name': _nameController.text.trim(),
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.auth.error ?? 'Error al registrar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);

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
                      const SizedBox(height: 32),
                      Text(
                        'Crear cuenta',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppThemeColors.titleColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      Text(
                        '¿Quién eres?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              label: 'Vendedor',
                              icon: Icons.storefront_outlined,
                              selected: _selectedRole == SignupRole.vendedor,
                              color: AppColors.orangeBright,
                              onTap: () => setState(() => _selectedRole = SignupRole.vendedor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _RoleCard(
                              label: 'Comprador',
                              icon: Icons.shopping_bag_outlined,
                              selected: _selectedRole == SignupRole.comprador,
                              color: AppColors.blueNeon,
                              onTap: () => setState(() => _selectedRole = SignupRole.comprador),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      _SignupInputField(
                        controller: _nameController,
                        hint: 'Nombre de usuario',
                        icon: Icons.person_outline,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _SignupInputField(
                        controller: _emailController,
                        hint: 'tu@correo.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _SignupInputField(
                        controller: _passwordController,
                        hint: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppThemeColors.inputHint(context),
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _SignupInputField(
                        controller: _confirmPasswordController,
                        hint: 'Confirmar contraseña',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppThemeColors.inputHint(context),
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                          if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),
                      _PrimaryButton(
                        onPressed: widget.auth.loading ? null : _submit,
                        label: widget.auth.loading ? 'Cargando...' : 'Registrarse',
                      ),

                      if (widget.auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.auth.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],

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
                            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected ? color : Colors.transparent;
    final bgColor = selected
        ? color.withValues(alpha: isDark ? 0.25 : 0.15)
        : AppThemeColors.inputFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppThemeColors.titleColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
        hintStyle: TextStyle(color: AppThemeColors.inputHint(context), fontSize: 16),
        prefixIcon: Icon(icon, color: AppThemeColors.inputHint(context), size: 22),
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