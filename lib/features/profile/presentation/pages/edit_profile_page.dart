import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialFirstName,
    required this.initialLastName,
    required this.email,
    required this.initialPhone,
    required this.initialGender,
    required this.initialCity,
    required this.initialZone,
    required this.initialBirthDate,
    required this.initialPhotoKey,
  });

  final String initialFirstName;
  final String initialLastName;
  final String email;
  final String initialPhone;
  final String initialGender;
  final String initialCity;
  final String initialZone;
  final String initialBirthDate;
  final String initialPhotoKey;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _genderOptions = <String, String>{
    'male': 'Masculino',
    'female': 'Femenino',
    'other': 'Otro',
    'prefer_not_to_say': 'Prefiero no decirlo',
  };

  final RestClient _api = RestClient();
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _zoneController;
  late final TextEditingController _birthDateController;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _errorMessage;
  String? _selectedGender;

  File? _photoFile;
  String? _photoKey;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _cityController = TextEditingController(text: widget.initialCity);
    _zoneController = TextEditingController(text: widget.initialZone);
    _birthDateController = TextEditingController(text: widget.initialBirthDate);

    _selectedGender = _genderOptions.containsKey(widget.initialGender)
        ? widget.initialGender
        : null;

    _photoKey = widget.initialPhotoKey.trim().isEmpty ? null : widget.initialPhotoKey.trim();
    _loadExistingPhoto();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _zoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto() async {
    if (_photoKey == null) return;

    try {
      final response = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(_photoKey!),
      ).result;

      if (!mounted) return;
      setState(() => _photoUrl = response.url.toString());
    } catch (_) {}
  }

  Future<void> _pickBirthDate() async {
    final initialDate = _tryParseBirthDate(_birthDateController.text) ?? DateTime(2000, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');

    _birthDateController.text = '$yyyy-$mm-$dd';
    setState(() {});
  }

  DateTime? _tryParseBirthDate(String value) {
    try {
      if (value.trim().isEmpty) return null;
      return DateTime.parse(value.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    setState(() => _errorMessage = null);

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        _photoFile = file;
        _uploadingPhoto = true;
      });

      final key =
          'public/profile/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_avatar.jpg';

      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(file.path),
        path: StoragePath.fromString(key),
      ).result;

      if (!mounted) return;

      final photoKey = result.uploadedItem.path;
      final urlResponse = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(photoKey),
      ).result;

      setState(() {
        _photoKey = photoKey;
        _photoUrl = urlResponse.url.toString();
      });
    } on StorageException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo subir la foto.');
      AppSnackbar.error(context, 'No se pudo subir la foto.');
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo subir la foto.');
      AppSnackbar.error(context, 'No se pudo subir la foto.');
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      await _api.put('/users/me', {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'city': _cityController.text.trim(),
        'zone': _zoneController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'photoKey': _photoKey,
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
    final subtitleColor = AppThemeColors.subtitleColor(context);

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
                const SizedBox(height: 8),
                Text(
                  'Actualiza cómo quieres aparecer en la app.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 96,
                          height: 96,
                          color: AppThemeColors.inputFill(context),
                          child: _photoFile != null
                              ? Image.file(_photoFile!, fit: BoxFit.cover)
                              : (_photoUrl != null
                              ? Image.network(_photoUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.person_outline, size: 42)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: _uploadingPhoto || _saving ? null : _pickAndUploadPhoto,
                        icon: _uploadingPhoto
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.photo_camera_back_outlined),
                        label: Text(_uploadingPhoto ? 'Subiendo…' : 'Cambiar foto'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: widget.email,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombres',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Ingresa tus nombres';
                    if (text.length < 2) return 'Nombre no válido';
                    if (text.length > 40) return 'Máximo 40 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Ingresa tus apellidos';
                    if (text.length < 2) return 'Apellido no válido';
                    if (text.length > 60) return 'Máximo 60 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+591 71234567',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Género',
                  ),
                  items: _genderOptions.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(),
                  onChanged: _saving ? null : (value) => setState(() => _selectedGender = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _zoneController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Zona',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
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
                  child: FilledButton.icon(
                    onPressed: _saving || _uploadingPhoto ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
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