import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final RestClient _api = RestClient();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _loading = true;
  String? _errorMessage;

  String _userId = '';
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get('/users/me');

      if (!mounted) return;

      setState(() {
        _userId = (response['userId'] ?? '').toString();
        _name = (response['name'] ?? '').toString();
        _email = (response['email'] ?? '').toString();
        _loading = false;
      });

      _animationController.forward(from: 0);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = UserFriendlyMessages.fromApiError(error);
        _loading = false;
      });
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = UserFriendlyMessages.fromGenericError(error);
        _loading = false;
      });
    }
  }

  String _buildInitials(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return 'U';

    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return trimmed[0].toUpperCase();
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: _name,
          email: _email,
        ),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _signOut() async {
    try {
      await Amplify.Auth.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
            (_) => false,
      );
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      AppSnackbar.error(context, 'No se pudo cerrar sesión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final isVendorMode = shell?.mode == MainShellMode.vendor;

    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);

    final displayName = _name.trim().isNotEmpty ? _name.trim() : 'Sin nombre';
    final displayEmail =
    _email.trim().isNotEmpty ? _email.trim() : 'Sin correo';
    final initials = _buildInitials(
      _name.trim().isNotEmpty ? _name : _email,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            onPressed: () {
              if (shell == null) return;

              if (isVendorMode) {
                shell.switchToBuyer();
              } else {
                shell.switchToVendor();
              }
            },
            icon: Icon(
              isVendorMode
                  ? Icons.search_rounded
                  : Icons.storefront_rounded,
            ),
            tooltip: isVendorMode
                ? 'Cambiar a comprador'
                : 'Cambiar a vendedor',
          ),
          IconButton(
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
            opacity: _fadeAnimation,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fillColor,
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
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                          AppColors.blueNeon.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                            if (_userId.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${_userId.length > 10 ? '${_userId.substring(0, 10)}…' : _userId}',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _openEditProfile,
                        child: const Text('Editar'),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Cuenta',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.settings_outlined,
                  title: 'Ajustes',
                  subtitle: 'Tema y cambio rápido de modo',
                  onTap: () {
                    if (shell == null) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(
                          currentMode: shell.mode,
                          onModeChanged: shell.setMode,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orangeAccent,
                      side: const BorderSide(
                        color: AppColors.orangeAccent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: fillColor,
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
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: subtitleColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}