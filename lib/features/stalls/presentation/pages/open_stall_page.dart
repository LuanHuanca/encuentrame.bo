import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

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
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  final TextEditingController _inventoryController = TextEditingController();

  File? _stallPhotoFile;
  File? _productsPhotoFile;

  String? _stallPhotoKey;
  String? _productsPhotoKey;

  Position? _position;

  bool _gettingLocation = false;
  bool _uploadingStall = false;
  bool _uploadingProducts = false;
  bool _opening = false;

  bool _speechReady = false;
  bool _listening = false;

  String? _error;

  bool get _hasLocation => _position != null;
  bool get _hasStallPhoto => _stallPhotoKey != null;
  bool get _hasProductsPhoto => _productsPhotoKey != null;

  bool get _canOpen =>
      !_opening &&
          !_uploadingStall &&
          !_uploadingProducts &&
          !_gettingLocation &&
          _hasLocation &&
          _hasStallPhoto &&
          _hasProductsPhoto &&
          _inventoryController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _ensureLocation();
  }

  @override
  void dispose() {
    _inventoryController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize();
      if (!mounted) return;
      setState(() => _speechReady = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechReady = false);
    }
  }

  Future<void> _toggleMic() async {
    if (!_speechReady) {
      setState(() => _error = 'La función de voz no está disponible.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() => _error = null);

    String? localeId;
    try {
      final locales = await _speech.locales();
      final spanish = locales.where((l) => l.localeId.startsWith('es')).toList();
      if (spanish.isNotEmpty) localeId = spanish.first.localeId;
    } catch (_) {}

    await _speech.listen(
      localeId: localeId,
      onResult: (res) {
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;

        _inventoryController.text = text;
        _inventoryController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inventoryController.text.length),
        );

        if (mounted) setState(() {});
      },
    );

    if (mounted) setState(() => _listening = true);
  }

  Future<void> _ensureLocation() async {
    setState(() {
      _gettingLocation = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Activa el GPS para continuar.');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        setState(() => _error = 'Permiso de ubicación denegado.');
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        setState(() =>
        _error = 'Permiso de ubicación bloqueado. Habilítalo en ajustes.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = 'No pude obtener ubicación.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<File?> _takePhoto() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x == null) return null;
      return File(x.path);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return null;
      setState(() => _error = 'No pude abrir la cámara.');
      return null;
    }
  }

  Future<String> _uploadToS3({
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
    setState(() => _error = null);

    final f = await _takePhoto();
    if (f == null) return;

    setState(() {
      _stallPhotoFile = f;
      _stallPhotoKey = null;
      _uploadingStall = true;
    });

    try {
      final key = await _uploadToS3(file: f, kind: 'stall');
      if (!mounted) return;
      setState(() => _stallPhotoKey = key);
    } on StorageException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) setState(() => _error = 'Error subiendo foto del puesto.');
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) setState(() => _error = 'Error subiendo foto del puesto.');
    } finally {
      if (mounted) setState(() => _uploadingStall = false);
    }
  }

  Future<void> _captureProductsPhoto() async {
    setState(() => _error = null);

    final f = await _takePhoto();
    if (f == null) return;

    setState(() {
      _productsPhotoFile = f;
      _productsPhotoKey = null;
      _uploadingProducts = true;
    });

    try {
      final key = await _uploadToS3(file: f, kind: 'products');
      if (!mounted) return;
      setState(() => _productsPhotoKey = key);
    } on StorageException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) setState(() => _error = 'Error subiendo foto de productos.');
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) setState(() => _error = 'Error subiendo foto de productos.');
    } finally {
      if (mounted) setState(() => _uploadingProducts = false);
    }
  }

  Future<void> _open() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final inventoryText = _inventoryController.text.trim();

      if (widget.stallId.trim().isEmpty) {
        throw ApiClientException('stallId requerido');
      }
      if (!_hasLocation) {
        throw ApiClientException('Falta ubicación (activa GPS)');
      }
      if (!_hasStallPhoto) {
        throw ApiClientException('Falta foto del puesto (subida)');
      }
      if (!_hasProductsPhoto) {
        throw ApiClientException('Falta foto de productos (subida)');
      }
      if (inventoryText.isEmpty) {
        throw ApiClientException('Falta inventario (voz o texto)');
      }

      final lat = _position!.latitude;
      final lng = _position!.longitude;
      final acc = _position!.accuracy;

      await _api.post('/stalls/open', {
        'stallId': widget.stallId,
        'stallName': widget.stallName,
        'lat': lat,
        'lng': lng,
        'accuracy': acc,
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
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = e.message);
      AppSnackbar.error(context, e.message);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = 'Error inesperado.');
      AppSnackbar.error(context, 'Error inesperado.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stallName.isEmpty ? 'Abrir puesto' : 'Abrir • ${widget.stallName}',
        ),
        actions: [
          IconButton(
            onPressed: (_opening || _uploadingStall || _uploadingProducts)
                ? null
                : _ensureLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Checklist para abrir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: title,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ubicación + 2 fotos + inventario. Al abrir, el sistema guardará la dirección usando Amazon Location.',
            style: TextStyle(color: sub),
          ),
          const SizedBox(height: 14),

          _StepCard(
            title: '1) Ubicación',
            ok: _hasLocation,
            busy: _gettingLocation,
            okText: _position == null
                ? ''
                : 'Lista • ±${_position!.accuracy.toStringAsFixed(0)}m',
            badText: 'Falta (activa GPS)',
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
                'lat ${_position!.latitude.toStringAsFixed(6)} • lng ${_position!.longitude.toStringAsFixed(6)}',
                style: TextStyle(color: sub, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 12),

          _PhotoStepCard(
            title: '2) Foto del puesto / entorno',
            file: _stallPhotoFile,
            ok: _hasStallPhoto,
            busy: _uploadingStall,
            onTake: (_opening || _uploadingStall) ? null : _captureStallPhoto,
          ),

          const SizedBox(height: 10),

          _PhotoStepCard(
            title: '3) Foto de productos (mesa)',
            file: _productsPhotoFile,
            ok: _hasProductsPhoto,
            busy: _uploadingProducts,
            onTake:
            (_opening || _uploadingProducts) ? null : _captureProductsPhoto,
          ),

          const SizedBox(height: 16),

          _StepCard(
            title: '4) Inventario (voz o texto)',
            ok: _inventoryController.text.trim().isNotEmpty,
            busy: false,
            okText: 'Listo',
            badText: 'Escribe o dicta tu inventario',
            trailing: IconButton.filledTonal(
              onPressed:
              (_opening || _uploadingStall || _uploadingProducts) ? null : _toggleMic,
              icon: Icon(_listening ? Icons.mic_off : Icons.mic),
              tooltip: _listening ? 'Detener' : 'Hablar',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _inventoryController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Inventario',
                  hintText: 'Ej: 2 poleras, 1 gorra, 3 medias...',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
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

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: _canOpen ? _open : null,
            icon: _opening
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.play_arrow),
            label: Text(_opening ? 'Abriendo…' : 'Abrir ahora'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.ok,
    required this.busy,
    required this.okText,
    required this.badText,
    required this.trailing,
    this.child,
  });

  final String title;
  final bool ok;
  final bool busy;
  final String okText;
  final String badText;
  final Widget trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sub = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(ok ? Icons.check_circle : Icons.error_outline, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      ok ? okText : badText,
                      style: t.bodySmall?.copyWith(color: sub),
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
    required this.ok,
    required this.busy,
    required this.onTake,
  });

  final String title;
  final File? file;
  final bool ok;
  final bool busy;
  final VoidCallback? onTake;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sub = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              height: 76,
              color: Colors.black12,
              child: file == null
                  ? const Icon(Icons.photo_camera, size: 28)
                  : Image.file(file!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 4),
                Text(
                  busy
                      ? 'Subiendo…'
                      : ok
                      ? 'Subida ✅'
                      : 'Pendiente',
                  style: t.bodySmall?.copyWith(color: sub),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : onTake,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(file == null ? 'Tomar foto' : 'Repetir'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked),
        ],
      ),
    );
  }
}