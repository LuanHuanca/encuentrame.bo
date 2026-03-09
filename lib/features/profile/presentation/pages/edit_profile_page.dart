import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialName,
    required this.email,
  });

  final String initialName;
  final String email;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final RestClient _api = RestClient();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      await _api.put('/users/me', {
        'name': _nameController.text.trim(),
      });

      if (!mounted) return;

      AppSnackbar.success(context, 'Perfil actualizado.');
      Navigator.pop(context, true);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      final message = UserFriendlyMessages.fromApiError(error);

      setState(() => _errorMessage = message);
      AppSnackbar.error(context, message);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      final message = UserFriendlyMessages.fromGenericError(error);

      setState(() => _errorMessage = message);
      AppSnackbar.error(context, message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Datos de tu cuenta',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.email,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveProfile(),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Tu nombre',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();

                    if (text.isEmpty) {
                      return 'Ingresa tu nombre';
                    }

                    if (text.length < 2) {
                      return 'Nombre no válido';
                    }

                    if (text.length > 60) {
                      return 'Máximo 60 caracteres';
                    }

                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
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