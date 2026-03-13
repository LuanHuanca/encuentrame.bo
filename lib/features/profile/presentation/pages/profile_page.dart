import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router.dart';
import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/app_info.dart';
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
  String _firstName = '';
  String _lastName = '';
  String _displayName = '';
  String _email = '';
  String _phone = '';
  String _gender = '';
  String _city = '';
  String _zone = '';
  String _birthDate = '';
  String _photoKey = '';
  int _profileCompletion = 0;
  String? _updatedAt;
  String? _photoUrl;

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

  Future<String?> _getStorageUrl(String key) async {
    try {
      final response = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(key),
      ).result;
      return response.url.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get('/users/me');

      final photoKey = (response['photoKey'] ?? '').toString().trim();
      String? photoUrl;
      if (photoKey.isNotEmpty) {
        photoUrl = await _getStorageUrl(photoKey);
      }

      if (!mounted) return;

      setState(() {
        _userId = (response['userId'] ?? '').toString();
        _firstName = (response['firstName'] ?? '').toString();
        _lastName = (response['lastName'] ?? '').toString();
        _displayName = (response['displayName'] ?? response['name'] ?? '').toString();
        _email = (response['email'] ?? '').toString();
        _phone = (response['phone'] ?? '').toString();
        _gender = (response['gender'] ?? '').toString();
        _city = (response['city'] ?? '').toString();
        _zone = (response['zone'] ?? '').toString();
        _birthDate = (response['birthDate'] ?? '').toString();
        _photoKey = photoKey;
        _photoUrl = photoUrl;
        _profileCompletion = (response['profileCompletion'] as num?)?.toInt() ?? 0;
        _updatedAt = response['updatedAt']?.toString();
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

  String _buildInitials() {
    final source = _displayName.trim().isNotEmpty ? _displayName : _email;
    final trimmed = source.trim();

    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return parts.first[0].toUpperCase();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sin registro';

    try {
      final date = DateTime.parse(iso).toLocal();
      String twoDigits(int value) => value.toString().padLeft(2, '0');

      return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
          '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _formatGender(String value) {
    switch (value) {
      case 'male':
        return 'Masculino';
      case 'female':
        return 'Femenino';
      case 'other':
        return 'Otro';
      case 'prefer_not_to_say':
        return 'Prefiero no decirlo';
      default:
        return value.trim().isEmpty ? 'No definido' : value;
    }
  }

  Future<void> _copyUserId() async {
    if (_userId.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _userId));

    if (!mounted) return;
    AppSnackbar.success(context, 'ID copiado.');
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialFirstName: _firstName,
          initialLastName: _lastName,
          email: _email,
          initialPhone: _phone,
          initialGender: _gender,
          initialCity: _city,
          initialZone: _zone,
          initialBirthDate: _birthDate,
          initialPhotoKey: _photoKey,
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

    final displayName = _displayName.trim().isNotEmpty
        ? _displayName.trim()
        : (_email.trim().isNotEmpty ? _email.split('@').first : 'Usuario');

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
              isVendorMode ? Icons.search_rounded : Icons.storefront_rounded,
            ),
            tooltip: isVendorMode ? 'Cambiar a comprador' : 'Cambiar a vendedor',
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
              : _errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 52,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
              : FadeTransition(
            opacity: _fadeAnimation,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (_photoUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _photoUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.blueNeon.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _buildInitials(),
                                style: const TextStyle(
                                  color: AppColors.blueNeon,
                                  fontSize: 22,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email.trim().isNotEmpty ? _email.trim() : 'Sin correo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.verified_user_outlined,
                                      label: 'Perfil $_profileCompletion%',
                                    ),
                                    _InfoChip(
                                      icon: Icons.info_outline,
                                      label: 'Build ${AppInfo.appVersion}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _openEditProfile,
                              child: const Text('Editar perfil'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Datos personales',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileInfoCard(
                  fillColor: fillColor,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  items: [
                    _ProfileInfoItem(
                      icon: Icons.person_outline,
                      title: 'Nombres',
                      value: _firstName.trim().isNotEmpty ? _firstName : 'No definido',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.badge_outlined,
                      title: 'Apellidos',
                      value: _lastName.trim().isNotEmpty ? _lastName : 'No definido',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.phone_outlined,
                      title: 'Teléfono',
                      value: _phone.trim().isNotEmpty ? _phone : 'No definido',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.wc_outlined,
                      title: 'Género',
                      value: _formatGender(_gender),
                    ),
                    _ProfileInfoItem(
                      icon: Icons.location_city_outlined,
                      title: 'Ciudad',
                      value: _city.trim().isNotEmpty ? _city : 'No definida',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.place_outlined,
                      title: 'Zona',
                      value: _zone.trim().isNotEmpty ? _zone : 'No definida',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.cake_outlined,
                      title: 'Fecha de nacimiento',
                      value: _birthDate.trim().isNotEmpty ? _birthDate : 'No definida',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Información de cuenta',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileInfoCard(
                  fillColor: fillColor,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  items: [
                    _ProfileInfoItem(
                      icon: Icons.email_outlined,
                      title: 'Correo',
                      value: _email.trim().isNotEmpty ? _email : 'Sin correo',
                    ),
                    _ProfileInfoItem(
                      icon: Icons.update_outlined,
                      title: 'Última actualización',
                      value: _formatDate(_updatedAt),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Identificador',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID de usuario',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _userId.isEmpty ? 'No disponible' : _userId,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _userId.isEmpty ? null : _copyUserId,
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copiar ID',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: subtitleColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoItem {
  const _ProfileInfoItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.fillColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.items,
  });

  final Color fillColor;
  final Color titleColor;
  final Color subtitleColor;
  final List<_ProfileInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon),
              title: Text(
                items[i].title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                items[i].value,
                style: TextStyle(color: subtitleColor),
              ),
            ),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
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