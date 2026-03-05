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
  String? _error;

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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();

      await _api.put('/users/me', {'name': name});

      if (!mounted) return;
      AppSnackbar.success(context, 'Perfil actualizado.');
      Navigator.pop(context, true);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = UserFriendlyMessages.fromApiError(e));
      AppSnackbar.error(context, _error!);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = UserFriendlyMessages.fromGenericError(e));
      AppSnackbar.error(context, _error!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Datos de tu cuenta',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

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
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Tu nombre',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Ingresa tu nombre';
                  if (value.length < 2) return 'Nombre no válido';
                  if (value.length > 60) return 'Máximo 60 caracteres';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}