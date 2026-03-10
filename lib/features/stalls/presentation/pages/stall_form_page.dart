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
    this.initialCategory,
    this.initialDescription,
  });

  final String? stallId;
  final String? initialName;
  final String? initialCategory;
  final String? initialDescription;

  @override
  State<StallFormPage> createState() => _StallFormPageState();
}

class _StallFormPageState extends State<StallFormPage> {
  static const List<String> _categories = [
    'Comida',
    'Bebidas',
    'Ropa',
    'Accesorios',
    'Tecnología',
    'Servicios',
    'Otros',
  ];

  final RestClient _api = RestClient();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _selectedCategory;
  bool _saving = false;

  bool get _isCreate => widget.stallId == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );

    final initialCategory = widget.initialCategory?.trim();
    _selectedCategory = _categories.contains(initialCategory)
        ? initialCategory
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
      };

      if (_isCreate) {
        await _api.post('/stalls', payload);

        if (!mounted) return;
        AppSnackbar.success(context, 'Puesto creado.');
      } else {
        await _api.put('/stalls/${widget.stallId}', payload);

        if (!mounted) return;
        AppSnackbar.success(context, 'Puesto actualizado.');
      }

      Navigator.pop(context, true);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
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
                  _isCreate ? 'Crea tu puesto' : 'Edita tu puesto',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCreate
                      ? 'Agrega un nombre claro, una categoría y una descripción breve para que tu puesto se vea mejor.'
                      : 'Actualiza la información principal de tu puesto.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del puesto',
                    hintText: 'Ejemplo: Pipocas Don Luis',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();

                    if (text.isEmpty) return 'El nombre es obligatorio';
                    if (text.length < 2) return 'El nombre es demasiado corto';
                    if (text.length > 60) return 'Máximo 60 caracteres';

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoría del puesto',
                  ),
                  items: _categories
                      .map(
                        (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText:
                    'Ejemplo: pipocas, bebidas frías, snacks o productos que sueles vender',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length > 180) {
                      return 'Máximo 180 caracteres';
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