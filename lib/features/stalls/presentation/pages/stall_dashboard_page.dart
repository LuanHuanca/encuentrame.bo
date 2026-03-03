import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/dialogs/app_confirm_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

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
  final RestClient _api = RestClient();

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

      _stallPhotoUrl = stallPhotoKey == null ? null : await _getUrl(stallPhotoKey);
      _productsPhotoUrl = productsPhotoKey == null ? null : await _getUrl(productsPhotoKey);
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      _error = UserFriendlyMessages.fromApiError(e);
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      _error = UserFriendlyMessages.fromGenericError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'Cerrar puesto',
      message: '¿Cerrar tu puesto ahora? Podrás volver a abrir cuando quieras.',
      confirmLabel: 'Cerrar',
      cancelLabel: 'Cancelar',
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.post('/stalls/${widget.stallId}/close', {});
      if (!mounted) return;
      AppSnackbar.success(context, 'Puesto cerrado.');
      Navigator.pop(context);
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      if (mounted) setState(() => _error = UserFriendlyMessages.fromApiError(e));
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      if (mounted) setState(() => _error = UserFriendlyMessages.fromGenericError(e));
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

    final opening = _opening;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 16),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (opening == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Este puesto no está abierto en este momento.',
              style: TextStyle(color: sub),
            ),
          ),
        ),
      );
    }

    final items = (opening['inventoryItems'] as List?)?.cast<dynamic>() ?? const [];
    final visionOnly =
        (opening['inventoryVisionOnly'] as List?)?.cast<dynamic>() ?? const [];

    final addressLabel = (opening['addressLabel'] ??
        _stall?['currentAddressLabel'] ??
        '')
        .toString()
        .trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _close, icon: const Icon(Icons.stop_circle)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _stall?['name']?.toString() ?? widget.stallName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: title,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${opening['status'] ?? 'OPEN'} • ${opening['openedAt'] ?? ''}',
            style: TextStyle(color: sub),
          ),

          if (addressLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AddressCard(
              label: addressLabel,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: addressLabel));
                if (context.mounted) AppSnackbar.success(context, 'Dirección copiada.');
              },
            ),
          ],

          const SizedBox(height: 16),
          _OsmLocationCard(opening: opening),

          const SizedBox(height: 16),
          Text(
            'Imágenes',
            style: TextStyle(
              color: title,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ImageCard(label: 'Puesto / entorno', url: _stallPhotoUrl),
          const SizedBox(height: 10),
          _ImageCard(label: 'Productos (mesa)', url: _productsPhotoUrl),

          const SizedBox(height: 16),
          Text(
            'Inventario',
            style: TextStyle(
              color: title,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _InventorySection(
            title: 'Confirmado (voz/texto)',
            items: items,
            empty: 'Sin items',
          ),
          const SizedBox(height: 10),
          _InventorySection(
            title: 'Sugerido por foto',
            items: visionOnly,
            empty: 'Sin sugerencias',
          ),

          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Ver etiquetas (Rekognition)',
              style: TextStyle(fontSize: 14, color: title),
            ),
            children: [
              _LabelsBlock(
                title: 'Labels detectados',
                labels: (opening['rekognitionLabels'] as List?)?.cast<dynamic>(),
              ),
              const SizedBox(height: 10),
              _LabelsBlock(
                title: 'Moderación',
                labels: (opening['moderationLabels'] as List?)?.cast<dynamic>(),
                emptyText: 'Sin alertas ✅',
              ),
              const SizedBox(height: 8),
            ],
          ),

          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Ver texto original',
              style: TextStyle(fontSize: 14, color: title),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  (opening['inventoryRaw'] ?? '').toString(),
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

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.label, required this.onCopy});

  final String label;
  final VoidCallback onCopy;

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
      child: Row(
        children: [
          const Icon(Icons.place_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dirección (Amazon Location)',
                    style: TextStyle(color: title, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: sub)),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copiar',
          ),
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

    if (lat == null || lng == null) {
      return Text('Sin ubicación', style: TextStyle(color: sub));
    }

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
            style: TextStyle(color: title, fontWeight: FontWeight.w800),
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
          Text(label, style: TextStyle(color: title, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (url == null)
            Text('No disponible', style: TextStyle(color: sub))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelsBlock extends StatelessWidget {
  const _LabelsBlock({
    required this.title,
    required this.labels,
    this.emptyText = 'Sin datos',
  });
  final String title;
  final List<dynamic>? labels;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    final list = labels ?? const [];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('$title: $emptyText', style: TextStyle(color: sub)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: t, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((x) {
              final m = (x as Map).cast<String, dynamic>();
              final name = (m['name'] ?? '').toString();
              final conf = (m['confidence'] ?? '').toString();
              return Chip(label: Text(conf.isEmpty ? name : '$name • $conf'));
            }).toList(),
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
            final display =
            (m['display'] ?? m['canonical'] ?? 'Producto').toString();
            final qty = (m['qty'] ?? 1).toString();
            final unit = (m['unit'] ?? 'unidad').toString();
            final suggested = m['suggested'] == true;

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                suggested ? Icons.lightbulb_outline : Icons.check_circle_outline,
              ),
              title: Text(display),
              subtitle: Text('x$qty $unit'),
              trailing: Text('x$qty'),
            );
          }),
        ],
      ),
    );
  }
}