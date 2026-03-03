import 'package:flutter/material.dart';

import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class StallFormPage extends StatefulWidget {
  const StallFormPage({super.key, this.stallId, this.initialName});

  final String? stallId;
  final String? initialName;

  @override
  State<StallFormPage> createState() => _StallFormPageState();
}

class _StallFormPageState extends State<StallFormPage> {
  final RestClient _api = RestClient();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
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

      if (widget.stallId == null) {
        await _api.post('/stalls', {'name': name});
        if (mounted) AppSnackbar.success(context, 'Puesto creado.');
      } else {
        await _api.put('/stalls/${widget.stallId}', {'name': name});
        if (mounted) AppSnackbar.success(context, 'Puesto actualizado.');
      }

      if (mounted) Navigator.pop(context, true);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, 'Error inesperado.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.stallId == null;

    return Scaffold(
      appBar: AppBar(title: Text(isCreate ? 'Crear puesto' : 'Editar puesto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Nombre del puesto',
                  hintText: 'Ej: Puesto de Poleras',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Nombre requerido';
                  if (value.length < 2) return 'Nombre no válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
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
    );
  }
}