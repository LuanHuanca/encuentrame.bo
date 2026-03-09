import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class StallFormPage extends StatefulWidget {
  const StallFormPage({
    super.key,
    this.stallId,
    this.initialName,
  });

  final String? stallId;
  final String? initialName;

  @override
  State<StallFormPage> createState() => _StallFormPageState();
}

class _StallFormPageState extends State<StallFormPage> {
  final RestClient _api = RestClient();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool _saving = false;

  bool get _isCreate => widget.stallId == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();

      if (_isCreate) {
        await _api.post('/stalls', {'name': name});

        if (!mounted) return;

        AppSnackbar.success(context, 'Puesto creado.');
      } else {
        await _api.put('/stalls/${widget.stallId}', {'name': name});

        if (!mounted) return;

        AppSnackbar.success(context, 'Nombre del puesto actualizado.');
      }

      Navigator.pop(context, true);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      AppSnackbar.error(
        context,
        UserFriendlyMessages.fromApiError(error),
      );
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      AppSnackbar.error(
        context,
        UserFriendlyMessages.fromGenericError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Crear puesto' : 'Editar puesto'),
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
                  _isCreate ? 'Crea tu puesto' : 'Edita el nombre de tu puesto',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCreate
                      ? 'Usa un nombre simple para identificar tu carrito o puesto ambulante.'
                      : 'Actualiza el nombre con el que quieres aparecer.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del puesto',
                    hintText: 'Ejemplo: Pipocas Don Luis',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();

                    if (text.isEmpty) {
                      return 'El nombre es obligatorio';
                    }

                    if (text.length < 2) {
                      return 'El nombre es demasiado corto';
                    }

                    if (text.length > 60) {
                      return 'Máximo 60 caracteres';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar'),
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