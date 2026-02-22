import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../shared/api/rest_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final api = RestClient();

  bool loading = true;
  String? _userName;
  String _role = '';
  String? _error;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _run();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final me = await api.get('/users/me');
      final role = (me['role'] as String?) ?? '';
      final name = me['name']?.toString();

      if (!mounted) return;

      if (role.isEmpty) {
        Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        return;
      }

      setState(() {
        _role = role;
        _userName = name;
        loading = false;
      });
      _animController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          loading = false;
        });
      }
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
          child: loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.blueNeon,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Cargando...',
                        style: TextStyle(color: subColor, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _run,
                  color: AppColors.bluePrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            _userName != null && _userName!.isNotEmpty
                                ? 'Hola, ${_userName!.split(' ').first}'
                                : 'Inicio',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Explora puestos y productos del mercado.',
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (_role == 'BUYER')
                                Chip(
                                  label: const Text('Comprador'),
                                  backgroundColor: AppColors.blueNeon
                                      .withValues(alpha: 0.2),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (_role == 'VENDOR')
                                Chip(
                                  label: const Text('Vendedor'),
                                  backgroundColor: AppColors.orangeBright
                                      .withValues(alpha: 0.2),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (_role == 'VENDOR') ...[
                            _HomeCard(
                              icon: Icons.storefront_rounded,
                              iconColor: AppColors.orangeBright,
                              title: 'Mis puestos',
                              subtitle:
                                  'Administra tus puestos, abre, cierra y gestiona productos.',
                              onTap: () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.stalls,
                                (r) => false,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _HomeCard(
                            icon: Icons.storefront_rounded,
                            iconColor: AppColors.blueNeon,
                            title: 'Modo comprador',
                            subtitle:
                                'Próximamente podrás ver puestos abiertos y comprar.',
                          ),
                          const SizedBox(height: 16),
                          _HomeCard(
                            icon: Icons.explore_rounded,
                            iconColor: AppColors.orangeBright,
                            title: 'Explorar',
                            subtitle: 'Encuentra lo que buscas cerca de ti.',
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error al cargar. Desliza para reintentar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subColor, fontSize: 14),
                              ),
                            ),
                          ],
                          const SizedBox(height: 100),
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

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    Widget card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subColor, fontSize: 14, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: card,
    );
  }
}
