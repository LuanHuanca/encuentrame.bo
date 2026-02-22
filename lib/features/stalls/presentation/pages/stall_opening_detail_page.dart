import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme.dart';

class StallOpeningDetailPage extends StatefulWidget {
  const StallOpeningDetailPage({
    super.key,
    required this.stallId,
    required this.stallName,
    required this.opening,
  });

  final String stallId;
  final String stallName;
  final Map<String, dynamic> opening;

  @override
  State<StallOpeningDetailPage> createState() => _StallOpeningDetailPageState();
}

class _StallOpeningDetailPageState extends State<StallOpeningDetailPage> {
  String? _stallPhotoUrl;
  String? _productsPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUrls();
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

  Future<void> _loadUrls() async {
    final stallPhotoKey = widget.opening['stallPhotoKey'] as String?;
    final productsPhotoKey = widget.opening['productsPhotoKey'] as String?;

    final a = stallPhotoKey == null ? null : await _getUrl(stallPhotoKey);
    final b = productsPhotoKey == null ? null : await _getUrl(productsPhotoKey);

    if (!mounted) return;
    setState(() {
      _stallPhotoUrl = a;
      _productsPhotoUrl = b;
    });
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    final o = widget.opening;
    final status = (o['status'] ?? '').toString();
    final openedAt = _fmtDate(o['openedAt']?.toString());
    final closedAt = _fmtDate(o['closedAt']?.toString());

    final items = (o['inventoryItems'] as List?)?.cast<dynamic>() ?? const [];
    final visionOnly = (o['inventoryVisionOnly'] as List?)?.cast<dynamic>() ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.stallName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            openedAt.isEmpty ? 'Apertura' : openedAt,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: title),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${status.isEmpty ? '—' : status}${closedAt.isEmpty ? '' : ' • Cerrado: $closedAt'}',
            style: TextStyle(color: sub),
          ),
          const SizedBox(height: 16),

          _OsmLocationCard(opening: o),

          const SizedBox(height: 16),
          Text('Imágenes', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _ImageCard(label: 'Puesto / entorno', url: _stallPhotoUrl),
          const SizedBox(height: 10),
          _ImageCard(label: 'Productos (mesa)', url: _productsPhotoUrl),

          const SizedBox(height: 16),
          Text('Rekognition', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _LabelsBlock(title: 'Labels detectados', labels: (o['rekognitionLabels'] as List?)?.cast<dynamic>()),
          const SizedBox(height: 10),
          _LabelsBlock(title: 'Moderación', labels: (o['moderationLabels'] as List?)?.cast<dynamic>(), emptyText: 'Sin alertas ✅'),

          const SizedBox(height: 16),
          Text('Inventario', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _InventorySection(title: 'Confirmado (voz/texto)', items: items, empty: 'Sin items'),
          const SizedBox(height: 10),
          _InventorySection(title: 'Sugerido por foto', items: visionOnly, empty: 'Sin sugerencias'),

          const SizedBox(height: 16),
          Text('Texto original', style: TextStyle(color: title, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text((o['inventoryRaw'] ?? '').toString(), style: TextStyle(color: sub)),
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
                options: MapOptions(initialCenter: center, initialZoom: 16),
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

class _InventorySection extends StatelessWidget {
  const _InventorySection({required this.title, required this.items, required this.empty});
  final String title;
  final List<dynamic> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);
    if (items.isEmpty) return Text('$title: $empty', style: TextStyle(color: sub));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...items.map((x) {
            final m = (x as Map).cast<String, dynamic>();
            final display = (m['display'] ?? m['canonical'] ?? 'Producto').toString();
            final qty = (m['qty'] ?? 1).toString();
            final unit = (m['unit'] ?? 'unidad').toString();
            final conf = (m['confidence'] ?? '').toString();
            final ev = (m['evidence'] is Map) ? (m['evidence'] as Map).cast<String, dynamic>() : <String, dynamic>{};
            final vision = (ev['vision'] as List?)?.cast<dynamic>() ?? const [];
            final suggested = m['suggested'] == true;

            final meta = <String>[];
            meta.add('x$qty $unit');
            if (conf.isNotEmpty) meta.add('conf: $conf');
            if (vision.isNotEmpty) meta.add('foto: ${vision.take(3).join(', ')}');
            if (suggested) meta.add('sugerido');

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(suggested ? Icons.lightbulb_outline : Icons.check_circle_outline),
              title: Text(display),
              subtitle: Text(meta.join(' • ')),
              trailing: Text('x$qty'),
            );
          }),
        ],
      ),
    );
  }
}