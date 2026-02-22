import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme.dart';
import '../../../../shared/api/rest_client.dart';

class StallDashboardPage extends StatefulWidget {
  const StallDashboardPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<StallDashboardPage> createState() => _StallDashboardPageState();
}

class _StallDashboardPageState extends State<StallDashboardPage> {
  final _api = RestClient();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _stall;
  Map<String, dynamic>? _opening;

  String? _stallPhotoUrl;
  String? _productsPhotoUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _getUrl(String key) async {
    try {
      final res = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(key),
      ).result;
      return res.url.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.get('/stalls/${widget.stallId}/current');
      _stall = (data['stall'] as Map?)?.cast<String, dynamic>();
      _opening = (data['opening'] as Map?)?.cast<String, dynamic>();

      final stallPhotoKey = _opening?['stallPhotoKey'] as String?;
      final productsPhotoKey = _opening?['productsPhotoKey'] as String?;

      if (stallPhotoKey != null) _stallPhotoUrl = await _getUrl(stallPhotoKey);
      if (productsPhotoKey != null) _productsPhotoUrl = await _getUrl(productsPhotoKey);
    } on ApiClientException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar puesto'),
        content: const Text('¿Cerrar tu puesto por hoy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.post('/stalls/${widget.stallId}/close', {});
      if (!mounted) return;
      Navigator.pop(context); // vuelve a lista
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Mi Puesto' : widget.stallName),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (_opening != null) IconButton(onPressed: _close, icon: const Icon(Icons.stop_circle)),
        ],
      ),
      body: _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      )
          : _opening == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Este puesto aún no está abierto hoy.',
            style: TextStyle(color: sub),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _stall?['name']?.toString() ?? widget.stallName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: title),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${_opening?['status'] ?? 'OPEN'} • ${_opening?['openedAt'] ?? ''}',
            style: TextStyle(color: sub),
          ),
          const SizedBox(height: 16),

          _OsmLocationCard(opening: _opening!),

          const SizedBox(height: 16),
          Text('Imágenes', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _ImageCard(label: 'Puesto / entorno', url: _stallPhotoUrl),
          const SizedBox(height: 10),
          _ImageCard(label: 'Productos (mesa)', url: _productsPhotoUrl),

          const SizedBox(height: 16),
          Text('Rekognition', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _LabelsBlock(
            title: 'Labels detectados',
            labels: (_opening?['rekognitionLabels'] as List?)?.cast<dynamic>(),
          ),
          const SizedBox(height: 10),
          _LabelsBlock(
            title: 'Moderación',
            labels: (_opening?['moderationLabels'] as List?)?.cast<dynamic>(),
            emptyText: 'Sin alertas ✅',
          ),

          const SizedBox(height: 16),
          Text('Inventario del día', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _InventoryBlock(items: (_opening?['inventoryItems'] as List?)?.cast<dynamic>()),
        ],
      ),
    );
  }
}

class _OsmLocationCard extends StatelessWidget {
  const _OsmLocationCard({required this.opening});
  final Map<String, dynamic> opening;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    final lat = (opening['lat'] as num?)?.toDouble();
    final lng = (opening['lng'] as num?)?.toDouble();
    final acc = (opening['accuracy'] as num?)?.toDouble();

    if (lat == null || lng == null) return Text('Sin ubicación', style: TextStyle(color: sub));

    final center = LatLng(lat, lng);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación', style: TextStyle(color: title, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'lat ${lat.toStringAsFixed(6)} • lng ${lng.toStringAsFixed(6)} • ±${(acc ?? 0).toStringAsFixed(0)}m',
            style: TextStyle(color: sub),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'encuentrame.bo',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.label, required this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: title, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (url == null)
            Text('No disponible', style: TextStyle(color: sub))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}

class _LabelsBlock extends StatelessWidget {
  const _LabelsBlock({required this.title, required this.labels, this.emptyText = 'Sin datos'});
  final String title;
  final List<dynamic>? labels;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    final list = labels ?? const [];
    if (list.isEmpty) return Text('$title: $emptyText', style: TextStyle(color: sub));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: t, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((x) {
              final m = (x as Map).cast<String, dynamic>();
              final name = (m['name'] ?? '').toString();
              final conf = (m['confidence'] ?? '').toString();
              return Chip(label: Text('$name • $conf'));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InventoryBlock extends StatelessWidget {
  const _InventoryBlock({required this.items});
  final List<dynamic>? items;

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);
    final list = items ?? const [];
    if (list.isEmpty) return Text('Aún no hay inventario procesado.', style: TextStyle(color: sub));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: list.map((x) {
          final m = (x as Map).cast<String, dynamic>();
          final name = (m['name'] ?? '').toString();
          final qty = (m['qty'] ?? '').toString();

          final matched = (m['matchedLabels'] as List?)?.cast<dynamic>() ?? const [];
          final score = (m['consensusScore'] ?? '').toString();

          final subtitle = <String>[];
          if (matched.isNotEmpty) subtitle.add('match: ${matched.join(', ')}');
          if (score.isNotEmpty) subtitle.add('score: $score');

          return ListTile(
            dense: true,
            title: Text(name),
            subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' • ')),
            trailing: Text('x$qty'),
          );
        }).toList(),
      ),
    );
  }
}