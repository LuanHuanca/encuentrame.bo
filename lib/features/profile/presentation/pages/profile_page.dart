import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final RestClient _api = RestClient();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  bool _loading = true;
  String? _error;

  String _userId = '';
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await _api.get('/users/me');

      final userId = (me['userId'] ?? '').toString();
      final name = (me['name'] ?? '').toString();
      final email = (me['email'] ?? '').toString();

      if (!mounted) return;

      setState(() {
        _userId = userId;
        _name = name;
        _email = email;
        _loading = false;
      });

      _animController.forward(from: 0);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyMessages.fromApiError(e);
        _loading = false;
      });
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyMessages.fromGenericError(e);
        _loading = false;
      });
    }
  }

  String _initials(String nameOrEmail) {
    final s = nameOrEmail.trim();
    if (s.isEmpty) return 'U';
    final parts = s.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return s[0].toUpperCase();
  }

  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: _name,
          email: _email,
        ),
      ),
    );

    if (ok == true) {
      await _load();
    }
  }

  Future<void> _signOut() async {
    try {
      await Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
            (_) => false,
      );
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      AppSnackbar.error(context, 'No se pudo cerrar sesión.');
    }
  }

  void _openPlaceholder(String title, String subtitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ComingSoonPage(title: title, subtitle: subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    final displayName = _name.trim().isNotEmpty ? _name.trim() : 'Sin nombre';
    final displayEmail = _email.trim().isNotEmpty ? _email.trim() : 'Sin correo';
    final initials = _initials(_name.trim().isNotEmpty ? _name : _email);

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
          child: _loading
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
                  'Cargando perfil...',
                  style: TextStyle(color: subColor, fontSize: 16),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _load,
            color: AppColors.bluePrimary,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mi perfil',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _edit,
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar perfil',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(16),
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
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color:
                              AppColors.blueNeon.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: AppColors.blueNeon,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayEmail,
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_userId.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${_userId.length > 10 ? '${_userId.substring(0, 10)}…' : _userId}',
                                    style: TextStyle(
                                      color: subColor.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _edit,
                            child: const Text('Editar'),
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 20),

                    Text(
                      'Acciones',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _ProfileTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Mis compras',
                      subtitle: 'Historial y estado de pedidos (próximo)',
                      onTap: () => _openPlaceholder(
                        'Mis compras',
                        'Aquí verás tu historial cuando activemos el módulo de compra.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ProfileTile(
                      icon: Icons.favorite_outline_rounded,
                      title: 'Favoritos',
                      subtitle: 'Puestos y productos guardados (próximo)',
                      onTap: () => _openPlaceholder(
                        'Favoritos',
                        'Aquí podrás guardar puestos y productos.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ProfileTile(
                      icon: Icons.settings_outlined,
                      title: 'Ajustes',
                      subtitle: 'Tema y preferencias (próximo)',
                      onTap: () => _openPlaceholder(
                        'Ajustes',
                        'Luego conectamos tema/notificaciones.',
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded, size: 22),
                        label: const Text('Cerrar sesión'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orangeAccent,
                          side: const BorderSide(color: AppColors.orangeAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.blueNeon, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction_rounded,
                    size: 64,
                    color: AppColors.blueNeon.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Próximamente',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppThemeColors.titleColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppThemeColors.subtitleColor(context),
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}