import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/api/rest_client.dart';
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
  final _api = RestClient();
  final _speech = SpeechToText();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  final _inventoryCtrl = TextEditingController();

  // Fotos locales (preview)
  File? _stallPhotoFile;
  File? _productsPhotoFile;

  // Keys S3 (lo que manda al backend)
  String? _stallPhotoKey;
  String? _productsPhotoKey;

  // Ubicación
  Position? _pos;

  bool _loading = false;
  String? _error;

  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _ensureLocation(); // intenta sacar ubicación apenas entra
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize();
    if (mounted) setState(() => _speechReady = ok);
  }

  Future<void> _toggleMic() async {
    if (!_speechReady) {
      setState(() => _error = 'Speech-to-text no disponible en este dispositivo');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() => _error = null);

    await _speech.listen(
      localeId: 'es_ES', // si el device soporta es_BO lo cambiamos luego
      onResult: (res) {
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;
        _inventoryCtrl.text = text;
        _inventoryCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _inventoryCtrl.text.length),
        );
        setState(() {});
      },
    );

    if (mounted) setState(() => _listening = true);
  }

  Future<void> _ensureLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Activa GPS para continuar');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        setState(() => _error = 'Permiso de ubicación denegado');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _error = 'Permiso de ubicación bloqueado. Habilítalo en ajustes.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) setState(() => _pos = pos);
    } catch (e) {
      setState(() => _error = 'No pude obtener ubicación: $e');
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
    } catch (e) {
      setState(() => _error = 'No pude abrir la cámara: $e');
      return null;
    }
  }

  Future<String> _uploadToS3({
    required File file,
    required String kind, // 'stall' | 'products'
  }) async {
    // Key estilo: public/vendor/<timestamp>_<uuid>_<kind>.jpg
    final key = 'public/vendor/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_$kind.jpg';

    final result = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      path: StoragePath.fromString(key),
    ).result;

    // result.uploadedItem.path == key (en v2 suele devolverte lo mismo)
    return result.uploadedItem.path;
  }

  Future<void> _captureStallPhoto() async {
    setState(() => _error = null);

    final f = await _takePhoto();
    if (f == null) return;

    setState(() {
      _stallPhotoFile = f;
      _stallPhotoKey = null; // reset si re-toma foto
    });

    try {
      setState(() => _loading = true);
      final key = await _uploadToS3(file: f, kind: 'stall');
      if (mounted) setState(() => _stallPhotoKey = key);
    } on StorageException catch (e) {
      setState(() => _error = 'Error subiendo foto del puesto: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Error subiendo foto del puesto: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureProductsPhoto() async {
    setState(() => _error = null);

    final f = await _takePhoto();
    if (f == null) return;

    setState(() {
      _productsPhotoFile = f;
      _productsPhotoKey = null;
    });

    try {
      setState(() => _loading = true);
      final key = await _uploadToS3(file: f, kind: 'products');
      if (mounted) setState(() => _productsPhotoKey = key);
    } on StorageException catch (e) {
      setState(() => _error = 'Error subiendo foto de productos: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Error subiendo foto de productos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasLocation => _pos != null;
  bool get _hasStallPhoto => _stallPhotoKey != null;
  bool get _hasProductsPhoto => _productsPhotoKey != null;

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final inventoryText = _inventoryCtrl.text.trim();

      if (widget.stallId.trim().isEmpty) throw ApiClientException('stallId requerido');
      if (!_hasLocation) throw ApiClientException('Falta ubicación (activa GPS)');
      if (!_hasStallPhoto) throw ApiClientException('Falta foto del puesto (subida)');
      if (!_hasProductsPhoto) throw ApiClientException('Falta foto de productos (subida)');
      if (inventoryText.isEmpty) throw ApiClientException('Falta inventario (voz o texto)');

      final lat = _pos!.latitude;
      final lng = _pos!.longitude;
      final acc = _pos!.accuracy;

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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StallDashboardPage(
            stallId: widget.stallId,
            stallName: widget.stallName,
          ),
        ),
      );
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _inventoryCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = !_loading && _hasLocation && _hasStallPhoto && _hasProductsPhoto && _inventoryCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Abrir puesto' : 'Abrir: ${widget.stallName}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _ensureLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusRow(
            title: 'Ubicación',
            ok: _hasLocation,
            okText: _pos == null ? '' : 'Lista • ±${_pos!.accuracy.toStringAsFixed(0)}m',
            badText: 'Falta (activa GPS)',
          ),

          const SizedBox(height: 12),

          Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          _PhotoCard(
            title: 'Puesto / entorno',
            file: _stallPhotoFile,
            ok: _hasStallPhoto,
            onTake: _loading ? null : _captureStallPhoto,
            subtitleOk: 'Subida ✅',
            subtitleBad: 'Toma una foto',
          ),

          const SizedBox(height: 10),

          _PhotoCard(
            title: 'Productos (mesa)',
            file: _productsPhotoFile,
            ok: _hasProductsPhoto,
            onTake: _loading ? null : _captureProductsPhoto,
            subtitleOk: 'Subida ✅',
            subtitleBad: 'Toma una foto',
          ),

          const SizedBox(height: 16),

          Text('Inventario', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inventoryCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Habla o escribe',
                    hintText: 'Ej: 2 poleras, 1 gorra, 3 medias...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  IconButton.filledTonal(
                    onPressed: _loading ? null : _toggleMic,
                    icon: Icon(_listening ? Icons.mic_off : Icons.mic),
                    tooltip: _listening ? 'Detener' : 'Hablar',
                  ),
                  Text(_listening ? 'Grabando' : 'Voz', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: canOpen ? _open : null,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
            label: Text(_loading ? 'Abriendo…' : 'Abrir hoy'),
          ),

          const SizedBox(height: 8),

          Text(
            'Checklist: ubicación + 2 fotos + inventario.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.ok,
    required this.okText,
    required this.badText,
  });

  final String title;
  final bool ok;
  final String okText;
  final String badText;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(ok ? okText : badText, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.file,
    required this.ok,
    required this.onTake,
    required this.subtitleOk,
    required this.subtitleBad,
  });

  final String title;
  final File? file;
  final bool ok;
  final VoidCallback? onTake;
  final String subtitleOk;
  final String subtitleBad;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
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
                Text(ok ? subtitleOk : subtitleBad, style: t.bodySmall),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onTake,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(file == null ? 'Tomar foto' : 'Repetir'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked),
        ],
      ),
    );
  }
}