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
    final isOpen = status.toUpperCase() == 'OPEN';
    final openedAt = _fmtDate(o['openedAt']?.toString());
    final closedAt = _fmtDate(o['closedAt']?.toString());

    final items = (o['inventoryItems'] as List?)?.cast<dynamic>() ?? const [];
    final visionOnly =
        (o['inventoryVisionOnly'] as List?)?.cast<dynamic>() ?? const [];
    final rekLabels =
        (o['rekognitionLabels'] as List?)?.cast<dynamic>() ?? const [];
    final modLabels =
        (o['moderationLabels'] as List?)?.cast<dynamic>() ?? const [];
    final imageUrls = [
      _stallPhotoUrl,
      _productsPhotoUrl,
    ].whereType<String>().toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.stallName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  openedAt.isEmpty ? 'Apertura' : openedAt,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: title,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.statusOpen.withValues(alpha: 0.15)
                      : AppColors.statusClosed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOpen ? 'Abierto' : 'Cerrado',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOpen
                        ? AppColors.statusOpen
                        : AppColors.statusClosed,
                  ),
                ),
              ),
            ],
          ),
          if (closedAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Cerrado: $closedAt',
              style: TextStyle(color: sub, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),

          if (imageUrls.isNotEmpty) ...[
            _ImageCarousel(urls: imageUrls),
            const SizedBox(height: 20),
          ],

          Text(
            'Inventario',
            style: TextStyle(
              color: title,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _InventorySection(
            title: 'Confirmado',
            items: items,
            empty: 'Sin items',
          ),
          const SizedBox(height: 8),
          _InventorySection(
            title: 'Sugerido por foto',
            items: visionOnly,
            empty: 'Sin sugerencias',
          ),
          const SizedBox(height: 16),

          _OsmLocationCard(opening: o),
          const SizedBox(height: 16),

          _CompactLabelsSection(
            rekognitionLabels: rekLabels,
            moderationLabels: modLabels,
          ),
          const SizedBox(height: 16),

          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Ver texto de voz original',
              style: TextStyle(fontSize: 14, color: title),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  (o['inventoryRaw'] ?? '').toString(),
                  style: TextStyle(color: sub, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLabelsSection extends StatelessWidget {
  const _CompactLabelsSection({
    required this.rekognitionLabels,
    required this.moderationLabels,
  });
  final List<dynamic> rekognitionLabels;
  final List<dynamic> moderationLabels;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);
    final rekCount = rekognitionLabels.length;
    final modCount = moderationLabels.length;
    final hasModAlerts = modCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasModAlerts
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
                color: hasModAlerts
                    ? AppColors.orangeBright
                    : AppColors.statusOpen,
              ),
              const SizedBox(width: 8),
              Text(
                hasModAlerts ? 'Revisar contenido' : 'Contenido OK',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rekCount > 0
                ? '$rekCount etiqueta${rekCount == 1 ? '' : 's'} detectada${rekCount == 1 ? '' : 's'} en la imagen.'
                : 'Sin etiquetas detectadas.',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          if (rekCount > 0 || modCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...rekognitionLabels.take(8).map((x) {
                  final m = (x as Map).cast<String, dynamic>();
                  final name = (m['name'] ?? '').toString();
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }),
                if (modCount > 0)
                  ...moderationLabels.take(4).map((x) {
                    final m = (x as Map).cast<String, dynamic>();
                    final name = (m['name'] ?? '').toString();
                    return Chip(
                      avatar: const Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppColors.orangeBright,
                      ),
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }),
              ],
            ),
          ],
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

    if (lat == null || lng == null)
      return Text('Sin ubicación', style: TextStyle(color: sub));

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
          Text(
            'Ubicación',
            style: TextStyle(color: title, fontWeight: FontWeight.w700),
          ),
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
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

class _InventorySection extends StatelessWidget {
  const _InventorySection({
    required this.title,
    required this.items,
    required this.empty,
  });
  final String title;
  final List<dynamic> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);
    if (items.isEmpty)
      return Text('$title: $empty', style: TextStyle(color: sub));

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
            final display = (m['display'] ?? m['canonical'] ?? 'Producto')
                .toString();
            final qty = (m['qty'] ?? 1).toString();
            final unit = (m['unit'] ?? 'unidad').toString();
            final conf = (m['confidence'] ?? '').toString();
            final ev = (m['evidence'] is Map)
                ? (m['evidence'] as Map).cast<String, dynamic>()
                : <String, dynamic>{};
            final vision = (ev['vision'] as List?)?.cast<dynamic>() ?? const [];
            final suggested = m['suggested'] == true;

            final meta = <String>[];
            meta.add('x$qty $unit');
            if (conf.isNotEmpty) meta.add('conf: $conf');
            if (vision.isNotEmpty)
              meta.add('foto: ${vision.take(3).join(', ')}');
            if (suggested) meta.add('sugerido');

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                suggested
                    ? Icons.lightbulb_outline
                    : Icons.check_circle_outline,
              ),
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
