import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'stall_dashboard_page.dart';

class OpenStallPage extends StatefulWidget {
  const OpenStallPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<OpenStallPage> createState() => _OpenStallPageState();
}

class _OpenStallPageState extends State<OpenStallPage> {
  final RestClient _api = RestClient();
  final SpeechToText _speech = SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  final TextEditingController _inventoryController = TextEditingController();

  File? _stallPhotoFile;
  File? _productsPhotoFile;

  String? _stallPhotoKey;
  String? _productsPhotoKey;

  Position? _position;

  bool _gettingLocation = false;
  bool _uploadingStallPhoto = false;
  bool _uploadingProductsPhoto = false;
  bool _openingStall = false;

  bool _speechReady = false;
  bool _isListening = false;

  String? _errorMessage;

  bool get _hasLocation => _position != null;
  bool get _hasStallPhoto => _stallPhotoKey != null;
  bool get _hasProductsPhoto => _productsPhotoKey != null;

  bool get _canSubmit {
    return !_openingStall &&
        !_gettingLocation &&
        !_uploadingStallPhoto &&
        !_uploadingProductsPhoto &&
        _hasLocation &&
        _hasStallPhoto &&
        _hasProductsPhoto &&
        _inventoryController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _ensureLocation();
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize();

      if (!mounted) return;

      setState(() => _speechReady = available);
    } catch (_) {
      if (!mounted) return;

      setState(() => _speechReady = false);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (!_speechReady) {
      setState(() => _errorMessage = 'La entrada por voz no está disponible.');
      return;
    }

    if (_isListening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() => _isListening = false);
      return;
    }

    setState(() => _errorMessage = null);

    String? localeId;

    try {
      final locales = await _speech.locales();
      final spanishLocales =
      locales.where((locale) => locale.localeId.startsWith('es')).toList();

      if (spanishLocales.isNotEmpty) {
        localeId = spanishLocales.first.localeId;
      }
    } catch (_) {}

    await _speech.listen(
      localeId: localeId,
      onResult: (result) {
        final text = result.recognizedWords.trim();

        if (text.isEmpty) return;

        _inventoryController.text = text;
        _inventoryController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inventoryController.text.length),
        );

        if (!mounted) return;

        setState(() {});
      },
    );

    if (!mounted) return;

    setState(() => _isListening = true);
  }

  Future<void> _ensureLocation() async {
    setState(() {
      _gettingLocation = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Activa el GPS para continuar.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = 'Permiso de ubicación denegado.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
          'Permiso de ubicación bloqueado. Habilítalo en ajustes.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() => _position = position);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'No se pudo obtener la ubicación.');
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<File?> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) return null;

      return File(pickedFile.path);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return null;

      setState(() => _errorMessage = 'No se pudo abrir la cámara.');
      return null;
    }
  }

  Future<String> _uploadImageToStorage({
    required File file,
    required String kind,
  }) async {
    final key =
        'public/vendor/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_$kind.jpg';

    final result = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      path: StoragePath.fromString(key),
    ).result;

    return result.uploadedItem.path;
  }

  Future<void> _captureStallPhoto() async {
    setState(() => _errorMessage = null);

    final file = await _takePhoto();
    if (file == null) return;

    setState(() {
      _stallPhotoFile = file;
      _stallPhotoKey = null;
      _uploadingStallPhoto = true;
    });

    try {
      final key = await _uploadImageToStorage(
        file: file,
        kind: 'stall',
      );

      if (!mounted) return;

      setState(() => _stallPhotoKey = key);
    } on StorageException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'Error subiendo la foto del puesto.');
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'Error subiendo la foto del puesto.');
    } finally {
      if (mounted) {
        setState(() => _uploadingStallPhoto = false);
      }
    }
  }

  Future<void> _captureProductsPhoto() async {
    setState(() => _errorMessage = null);

    final file = await _takePhoto();
    if (file == null) return;

    setState(() {
      _productsPhotoFile = file;
      _productsPhotoKey = null;
      _uploadingProductsPhoto = true;
    });

    try {
      final key = await _uploadImageToStorage(
        file: file,
        kind: 'products',
      );

      if (!mounted) return;

      setState(() => _productsPhotoKey = key);
    } on StorageException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'Error subiendo la foto de productos.');
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'Error subiendo la foto de productos.');
    } finally {
      if (mounted) {
        setState(() => _uploadingProductsPhoto = false);
      }
    }
  }

  Future<void> _openStall() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _openingStall = true;
      _errorMessage = null;
    });

    try {
      final inventoryText = _inventoryController.text.trim();

      if (widget.stallId.trim().isEmpty) {
        throw ApiClientException('stallId requerido');
      }

      if (!_hasLocation) {
        throw ApiClientException('Falta ubicación.');
      }

      if (!_hasStallPhoto) {
        throw ApiClientException('Falta la foto del puesto.');
      }

      if (!_hasProductsPhoto) {
        throw ApiClientException('Falta la foto de productos.');
      }

      if (inventoryText.isEmpty) {
        throw ApiClientException('Falta el inventario.');
      }

      await _api.post('/stalls/open', {
        'stallId': widget.stallId,
        'stallName': widget.stallName,
        'lat': _position!.latitude,
        'lng': _position!.longitude,
        'accuracy': _position!.accuracy,
        'stallPhotoKey': _stallPhotoKey,
        'productsPhotoKey': _productsPhotoKey,
        'inventoryText': inventoryText,
      });

      if (!mounted) return;

      AppSnackbar.success(context, 'Puesto abierto.');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StallDashboardPage(
            stallId: widget.stallId,
            stallName: widget.stallName,
          ),
        ),
      );
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = error.message);
      AppSnackbar.error(context, error.message);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'Error inesperado.');
      AppSnackbar.error(context, 'Error inesperado.');
    } finally {
      if (mounted) {
        setState(() => _openingStall = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stallName.isEmpty
              ? 'Abrir puesto'
              : 'Abrir • ${widget.stallName}',
        ),
        actions: [
          IconButton(
            onPressed: shell == null ? null : shell.switchToBuyer,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Cambiar a comprador',
          ),
          IconButton(
            onPressed: (_openingStall ||
                _uploadingStallPhoto ||
                _uploadingProductsPhoto)
                ? null
                : _ensureLocation,
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Checklist para publicar tu puesto',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Necesitamos tu ubicación actual, dos fotos y el inventario para que los compradores te encuentren.',
            style: TextStyle(color: subtitleColor),
          ),
          const SizedBox(height: 16),
          _StepCard(
            title: '1) Ubicación actual',
            isDone: _hasLocation,
            isBusy: _gettingLocation,
            successText: _position == null
                ? ''
                : 'Lista • precisión ±${_position!.accuracy.toStringAsFixed(0)} m',
            pendingText: 'Aún no se obtuvo la ubicación',
            trailing: IconButton(
              onPressed: _gettingLocation ? null : _ensureLocation,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
            child: _position == null
                ? null
                : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'lat ${_position!.latitude.toStringAsFixed(6)} • '
                    'lng ${_position!.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PhotoStepCard(
            title: '2) Foto del puesto o carrito',
            file: _stallPhotoFile,
            isDone: _hasStallPhoto,
            isBusy: _uploadingStallPhoto,
            onTakePhoto: (_openingStall || _uploadingStallPhoto)
                ? null
                : _captureStallPhoto,
          ),
          const SizedBox(height: 10),
          _PhotoStepCard(
            title: '3) Foto de los productos',
            file: _productsPhotoFile,
            isDone: _hasProductsPhoto,
            isBusy: _uploadingProductsPhoto,
            onTakePhoto: (_openingStall || _uploadingProductsPhoto)
                ? null
                : _captureProductsPhoto,
          ),
          const SizedBox(height: 12),
          _StepCard(
            title: '4) Inventario por voz o texto',
            isDone: _inventoryController.text.trim().isNotEmpty,
            isBusy: false,
            successText: 'Listo',
            pendingText: 'Describe qué estás vendiendo',
            trailing: IconButton.filledTonal(
              onPressed: (_openingStall ||
                  _uploadingStallPhoto ||
                  _uploadingProductsPhoto)
                  ? null
                  : _toggleVoiceInput,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              tooltip: _isListening ? 'Detener grabación' : 'Hablar',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _inventoryController,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Inventario',
                  hintText: 'Ejemplo: pipocas, api, 5 jugos, 3 empanadas',
                ),
              ),
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
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _canSubmit ? _openStall : null,
            icon: _openingStall
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.publish_rounded),
            label: Text(_openingStall ? 'Publicando…' : 'Publicar puesto'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.isDone,
    required this.isBusy,
    required this.successText,
    required this.pendingText,
    required this.trailing,
    this.child,
  });

  final String title;
  final bool isDone;
  final bool isBusy;
  final String successText;
  final String pendingText;
  final Widget trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isDone ? Icons.check_circle : Icons.error_outline,
                  size: 22,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone ? successText : pendingText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _PhotoStepCard extends StatelessWidget {
  const _PhotoStepCard({
    required this.title,
    required this.file,
    required this.isDone,
    required this.isBusy,
    required this.onTakePhoto,
  });

  final String title;
  final File? file;
  final bool isDone;
  final bool isBusy;
  final VoidCallback? onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 78,
              height: 78,
              color: Colors.black12,
              child: file == null
                  ? const Icon(Icons.photo_camera_rounded, size: 28)
                  : Image.file(file!, fit: BoxFit.cover),
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
                  isBusy
                      ? 'Subiendo…'
                      : (isDone ? 'Subida correctamente' : 'Pendiente'),
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onTakePhoto,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(file == null ? 'Tomar foto' : 'Repetir'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBusy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isDone
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
        ],
      ),
    );
  }
}