import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/app_dependencies.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

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
      await api.post('/users/me', {'role': role});
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
    } catch (e, stackTrace) {
      if (!mounted) return;
      UserFriendlyMessages.logToConsole(e, stackTrace);
      AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

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
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () async {
                            await AppDependencies.auth.signOut();
                            if (!mounted) return;
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (r) => false,
                            );
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: titleColor,
                          ),
                          tooltip: 'Cerrar sesión y volver',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¿Qué quieres hacer?',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Elige tu rol para continuar.',
                        style: TextStyle(color: subColor, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: loading ? null : () => _setRole('VENDOR'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront_outlined, size: 24),
                              const SizedBox(width: 12),
                              Text(loading ? 'Guardando...' : 'Soy Vendedor'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 56,
                        child: FilledButton.tonal(
                          onPressed: loading ? null : () => _setRole('BUYER'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 24),
                              const SizedBox(width: 12),
                              Text(loading ? 'Guardando...' : 'Soy Comprador'),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '¿Quieres usar otra cuenta?',
                        style: TextStyle(color: subColor, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () async {
                                  await AppDependencies.auth.signOut();
                                  if (!mounted) return;
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRoutes.login,
                                    (r) => false,
                                  );
                                },
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text('Cerrar sesión e iniciar con otra'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeColors.titleColor(context),
                            side: BorderSide(
                              color: AppThemeColors.subtitleColor(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
