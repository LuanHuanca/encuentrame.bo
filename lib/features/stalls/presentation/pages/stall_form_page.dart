import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
    this.initialMainPhotoKey,
    this.initialCoverPhotoKey,
    this.initialPaymentMethods,
    this.initialPriceRange,
    this.initialReferenceText,
    this.initialSchedule,
    this.initialLocationVisibility,
    this.initialActive,
  });

  final String? stallId;
  final String? initialName;
  final String? initialCategory;
  final String? initialDescription;
  final String? initialMainPhotoKey;
  final String? initialCoverPhotoKey;
  final List<String>? initialPaymentMethods;
  final String? initialPriceRange;
  final String? initialReferenceText;
  final List<Map<String, dynamic>>? initialSchedule;
  final String? initialLocationVisibility;
  final bool? initialActive;

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

  static const Map<String, String> _paymentLabels = {
    'cash': 'Efectivo',
    'qr': 'QR',
    'transfer': 'Transferencia',
  };

  static const Map<String, String> _priceLabels = {
    'economic': 'Económico',
    'medium': 'Medio',
    'premium': 'Premium',
  };

  static const Map<String, String> _visibilityLabels = {
    'exact': 'Exacta',
    'approximate': 'Aproximada',
  };

  static const Map<String, String> _dayLabels = {
    'mon': 'Lunes',
    'tue': 'Martes',
    'wed': 'Miércoles',
    'thu': 'Jueves',
    'fri': 'Viernes',
    'sat': 'Sábado',
    'sun': 'Domingo',
  };

  final RestClient _api = RestClient();
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _referenceController;

  String? _selectedCategory;
  String? _selectedPriceRange;
  String _selectedLocationVisibility = 'exact';
  bool _active = true;

  final Set<String> _paymentMethods = {};
  final List<Map<String, String>> _schedule = [];

  bool _saving = false;
  bool _uploadingMainPhoto = false;
  bool _uploadingCoverPhoto = false;

  String? _mainPhotoKey;
  String? _coverPhotoKey;
  String? _mainPhotoUrl;
  String? _coverPhotoUrl;

  bool get _isCreate => widget.stallId == null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _referenceController =
        TextEditingController(text: widget.initialReferenceText ?? '');

    final initialCategory = widget.initialCategory?.trim();
    _selectedCategory =
    _categories.contains(initialCategory) ? initialCategory : null;

    final initialPriceRange = widget.initialPriceRange?.trim();
    _selectedPriceRange =
    _priceLabels.containsKey(initialPriceRange) ? initialPriceRange : null;

    final initialLocationVisibility =
        widget.initialLocationVisibility?.trim() ?? '';
    if (_visibilityLabels.containsKey(initialLocationVisibility)) {
      _selectedLocationVisibility = initialLocationVisibility;
    }

    _active = widget.initialActive ?? true;

    _paymentMethods.addAll(
      (widget.initialPaymentMethods ?? const [])
          .where((item) => _paymentLabels.containsKey(item)),
    );

    final initialSchedule = widget.initialSchedule ?? const [];
    for (final item in initialSchedule) {
      final day = (item['day'] ?? '').toString();
      final from = (item['from'] ?? '').toString();
      final to = (item['to'] ?? '').toString();

      if (_dayLabels.containsKey(day) && from.isNotEmpty && to.isNotEmpty) {
        _schedule.add({
          'day': day,
          'from': from,
          'to': to,
        });
      }
    }

    _mainPhotoKey = (widget.initialMainPhotoKey ?? '').trim().isEmpty
        ? null
        : widget.initialMainPhotoKey!.trim();

    _coverPhotoKey = (widget.initialCoverPhotoKey ?? '').trim().isEmpty
        ? null
        : widget.initialCoverPhotoKey!.trim();

    _loadExistingPhotos();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhotos() async {
    if (_mainPhotoKey != null) {
      _mainPhotoUrl = await _getStorageUrl(_mainPhotoKey!);
    }

    if (_coverPhotoKey != null) {
      _coverPhotoUrl = await _getStorageUrl(_coverPhotoKey!);
    }

    if (!mounted) return;
    setState(() {});
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

  Future<void> _pickAndUploadPhoto({
    required bool isMain,
  }) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        if (isMain) {
          _uploadingMainPhoto = true;
        } else {
          _uploadingCoverPhoto = true;
        }
      });

      final key =
          'public/stalls/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_${isMain ? 'main' : 'cover'}.jpg';

      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(picked.path),
        path: StoragePath.fromString(key),
      ).result;

      final uploadedKey = result.uploadedItem.path;
      final uploadedUrl = await _getStorageUrl(uploadedKey);

      if (!mounted) return;

      setState(() {
        if (isMain) {
          _mainPhotoKey = uploadedKey;
          _mainPhotoUrl = uploadedUrl;
        } else {
          _coverPhotoKey = uploadedKey;
          _coverPhotoUrl = uploadedUrl;
        }
      });
    } on StorageException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      AppSnackbar.error(context, 'No se pudo subir la foto.');
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      AppSnackbar.error(context, 'No se pudo subir la foto.');
    } finally {
      if (!mounted) return;

      setState(() {
        _uploadingMainPhoto = false;
        _uploadingCoverPhoto = false;
      });
    }
  }

  Future<void> _addScheduleRow() async {
    final usedDays = _schedule.map((row) => row['day']).toSet();
    final availableDays =
    _dayLabels.keys.where((day) => !usedDays.contains(day)).toList();

    if (availableDays.isEmpty) {
      AppSnackbar.info(context, 'Ya agregaste los 7 días.');
      return;
    }

    String selectedDay = availableDays.first;
    TimeOfDay fromTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 18, minute: 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            String formatTime(TimeOfDay time) {
              final hh = time.hour.toString().padLeft(2, '0');
              final mm = time.minute.toString().padLeft(2, '0');
              return '$hh:$mm';
            }

            return AlertDialog(
              title: const Text('Agregar horario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'Día',
                    ),
                    items: availableDays
                        .map(
                          (day) => DropdownMenuItem<String>(
                        value: day,
                        child: Text(_dayLabels[day]!),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => selectedDay = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Desde'),
                    subtitle: Text(formatTime(fromTime)),
                    trailing: const Icon(Icons.access_time_rounded),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: fromTime,
                      );

                      if (picked == null) return;
                      setLocalState(() => fromTime = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hasta'),
                    subtitle: Text(formatTime(toTime)),
                    trailing: const Icon(Icons.access_time_filled_rounded),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: toTime,
                      );

                      if (picked == null) return;
                      setLocalState(() => toTime = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final fromMinutes = fromTime.hour * 60 + fromTime.minute;
                    final toMinutes = toTime.hour * 60 + toTime.minute;

                    if (fromMinutes >= toMinutes) {
                      AppSnackbar.error(
                        context,
                        'La hora inicial debe ser menor a la final.',
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    String formatTime(TimeOfDay time) {
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    setState(() {
      _schedule.add({
        'day': selectedDay,
        'from': formatTime(fromTime),
        'to': formatTime(toTime),
      });
    });
  }

  void _removeScheduleRow(int index) {
    setState(() => _schedule.removeAt(index));
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
        'mainPhotoKey': _mainPhotoKey,
        'coverPhotoKey': _coverPhotoKey,
        'paymentMethods': _paymentMethods.toList(),
        'priceRange': _selectedPriceRange,
        'referenceText': _referenceController.text.trim(),
        'schedule': _schedule,
        'locationVisibility': _selectedLocationVisibility,
        'active': _active,
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
                  _isCreate ? 'Configura tu puesto' : 'Actualiza tu puesto',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define cómo quieres que se vea tu puesto en la app y qué información pública vas a mostrar.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                _PhotoUploadCard(
                  title: 'Foto principal',
                  imageUrl: _mainPhotoUrl,
                  isUploading: _uploadingMainPhoto,
                  onPick: (_saving || _uploadingMainPhoto)
                      ? null
                      : () => _pickAndUploadPhoto(isMain: true),
                ),
                const SizedBox(height: 12),
                _PhotoUploadCard(
                  title: 'Foto de portada',
                  imageUrl: _coverPhotoUrl,
                  isUploading: _uploadingCoverPhoto,
                  onPick: (_saving || _uploadingCoverPhoto)
                      ? null
                      : () => _pickAndUploadPhoto(isMain: false),
                ),
                const SizedBox(height: 16),
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText:
                    'Ejemplo: bebidas frías, snacks, comida rápida o accesorios',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length > 240) {
                      return 'Máximo 240 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Referencia',
                    hintText: 'Ejemplo: frente al mercado...',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length > 160) {
                      return 'Máximo 160 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Métodos de pago',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentLabels.entries.map((entry) {
                    final selected = _paymentMethods.contains(entry.key);

                    return FilterChip(
                      selected: selected,
                      label: Text(entry.value),
                      onSelected: _saving
                          ? null
                          : (value) {
                        setState(() {
                          if (value) {
                            _paymentMethods.add(entry.key);
                          } else {
                            _paymentMethods.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPriceRange,
                  decoration: const InputDecoration(
                    labelText: 'Rango de precios',
                  ),
                  items: _priceLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selectedPriceRange = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedLocationVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibilidad de ubicación',
                  ),
                  items: _visibilityLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                    if (value == null) return;
                    setState(() => _selectedLocationVisibility = value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Horarios habituales',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : _addScheduleRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_schedule.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppThemeColors.inputFill(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Todavía no agregaste horarios.',
                      style: TextStyle(
                        color: subtitleColor,
                      ),
                    ),
                  )
                else
                  ...List.generate(_schedule.length, (index) {
                    final item = _schedule[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppThemeColors.inputFill(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_dayLabels[item['day']] ?? item['day']} • ${item['from']} - ${item['to']}',
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => _removeScheduleRow(index),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  onChanged: _saving ? null : (value) => setState(() => _active = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Puesto activo'),
                  subtitle: const Text(
                    'Desactívalo si no quieres mostrarlo por ahora.',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed:
                    (_saving || _uploadingMainPhoto || _uploadingCoverPhoto)
                        ? null
                        : _save,
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

class _PhotoUploadCard extends StatelessWidget {
  const _PhotoUploadCard({
    required this.title,
    required this.imageUrl,
    required this.isUploading,
    required this.onPick,
  });

  final String title;
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 86,
              height: 86,
              color: Colors.black12,
              child: imageUrl == null
                  ? const Icon(Icons.image_outlined, size: 28)
                  : Image.network(imageUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  isUploading
                      ? 'Subiendo…'
                      : (imageUrl == null ? 'Pendiente' : 'Lista'),
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: isUploading ? null : onPick,
                  icon: isUploading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(imageUrl == null ? 'Subir foto' : 'Cambiar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}