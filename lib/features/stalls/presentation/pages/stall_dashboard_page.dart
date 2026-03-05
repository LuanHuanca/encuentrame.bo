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
  bool _productsLoading = true;
  String? _error;

  Map<String, dynamic>? _stall;
  Map<String, dynamic>? _opening;

  String? _stallPhotoUrl;
  String? _productsPhotoUrl;

  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Future<String?> _getUrl(String key) async {
    try {
      final res = await Amplify.Storage.getUrl(path: StoragePath.fromString(key)).result;
      return res.url.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll() async {
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

      await _loadProducts(showLoader: true);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      _error = UserFriendlyMessages.fromApiError(e);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      _error = UserFriendlyMessages.fromGenericError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts({required bool showLoader}) async {
    if (showLoader && mounted) setState(() => _productsLoading = true);

    try {
      final res = await _api.get('/stalls/${widget.stallId}/products');
      final list = (res['products'] as List?)?.cast<dynamic>() ?? const [];
      _products = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _closeStall() async {
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
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> p) async {
    final productId = (p['productId'] ?? '').toString();
    if (productId.isEmpty) return;

    final nameCtrl = TextEditingController(text: (p['display'] ?? p['canonical'] ?? '').toString());
    final qtyCtrl = TextEditingController(text: (p['lastQty'] ?? 1).toString());
    bool active = p['active'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          return AlertDialog(
            title: const Text('Editar producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Activo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Guardar')),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      return;
    }

    final display = nameCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim());

    nameCtrl.dispose();
    qtyCtrl.dispose();

    final payload = <String, dynamic>{
      'active': active,
    };

    if (display.isNotEmpty) payload['display'] = display;
    if (qty != null) payload['lastQty'] = qty;

    setState(() => _productsLoading = true);
    try {
      await _api.put('/stalls/${widget.stallId}/products/$productId', payload);
      if (!mounted) return;
      AppSnackbar.success(context, 'Producto actualizado.');
      await _loadProducts(showLoader: false);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> p) async {
    final productId = (p['productId'] ?? '').toString();
    final name = (p['display'] ?? p['canonical'] ?? 'Producto').toString();
    if (productId.isEmpty) return;

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Eliminar producto',
      message: '¿Eliminar "$name" de tu lista?',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );
    if (ok != true) return;

    setState(() => _productsLoading = true);
    try {
      await _api.del('/stalls/${widget.stallId}/products/$productId');
      if (!mounted) return;
      AppSnackbar.success(context, 'Producto eliminado.');
      await _loadProducts(showLoader: false);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
          actions: [IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh))],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: sub, fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final opening = _opening;
    if (opening == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
          actions: [IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh))],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Este puesto no está abierto en este momento.', style: TextStyle(color: sub)),
          ),
        ),
      );
    }

    final addressLabel = (opening['addressLabel'] ?? _stall?['currentAddressLabel'] ?? '').toString().trim();
    final status = (opening['status'] ?? 'OPEN').toString();
    final openedAt = _fmtDate(opening['openedAt']?.toString());

    final invItems = (opening['inventoryItems'] as List?)?.cast<dynamic>() ?? const [];
    final suggestions = (opening['inventorySuggestions'] as List?)?.cast<dynamic>() ??
        (opening['inventoryVisionOnly'] as List?)?.cast<dynamic>() ??
        const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
          IconButton(onPressed: _closeStall, icon: const Icon(Icons.stop_circle), tooltip: 'Cerrar puesto'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _stall?['name']?.toString() ?? widget.stallName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: title),
            ),
            const SizedBox(height: 6),
            Text('Estado: $status • $openedAt', style: TextStyle(color: sub)),
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
            Text('Imágenes', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _ImageCard(label: 'Puesto / entorno', url: _stallPhotoUrl),
            const SizedBox(height: 10),
            _ImageCard(label: 'Productos (mesa)', url: _productsPhotoUrl),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Productos', style: TextStyle(color: title, fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                if (_productsLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(
                  onPressed: _productsLoading ? null : () => _loadProducts(showLoader: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar productos',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProductsTable(
              products: _products,
              subtitleColor: sub,
              onEdit: _editProduct,
              onDelete: _deleteProduct,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Inventario extraído (voz/texto)', style: TextStyle(fontSize: 14, color: title)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryList(items: invItems, emptyText: 'Sin items'),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Sugerencias por foto', style: TextStyle(fontSize: 14, color: title)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionsList(items: suggestions, emptyText: 'Sin sugerencias'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  const _ProductsTable({
    required this.products,
    required this.subtitleColor,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> products;
  final Color subtitleColor;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeColors.inputFill(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Aún no hay productos. Abre el puesto con inventario para generarlos.',
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(child: Text('Producto', style: TextStyle(fontWeight: FontWeight.w800))),
                SizedBox(width: 70, child: Text('Cantidad', style: TextStyle(color: subtitleColor))),
                const SizedBox(width: 64),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ...products.map((p) {
            final display = (p['display'] ?? p['canonical'] ?? 'Producto').toString();
            final qty = (p['lastQty'] ?? 0).toString();
            final active = p['active'] == true;

            return Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(active ? 'Activo' : 'Inactivo', style: TextStyle(color: subtitleColor)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 56, child: Text('x$qty', textAlign: TextAlign.right)),
                      IconButton(
                        onPressed: () => onEdit(p),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        onPressed: () => onDelete(p),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.items, required this.emptyText});

  final List<dynamic> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);

    if (items.isEmpty) return Text(emptyText, style: TextStyle(color: sub));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.map((x) {
          final m = (x as Map).cast<String, dynamic>();
          final display = (m['display'] ?? m['canonical'] ?? 'Producto').toString();
          final qty = (m['qty'] ?? 1).toString();
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(display),
            trailing: Text('x$qty'),
          );
        }).toList(),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.items, required this.emptyText});

  final List<dynamic> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);

    if (items.isEmpty) return Text(emptyText, style: TextStyle(color: sub));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((x) {
          if (x is Map) {
            final m = x.cast<String, dynamic>();
            final label = (m['label'] ?? m['name'] ?? m['display'] ?? '').toString();
            if (label.isEmpty) return const SizedBox.shrink();
            return Chip(label: Text(label));
          }
          final s = x.toString();
          return Chip(label: Text(s));
        }).toList(),
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
                Text('Dirección (Amazon Location)', style: TextStyle(color: title, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: sub)),
              ],
            ),
          ),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded), tooltip: 'Copiar'),
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
          Text('Ubicación', style: TextStyle(color: title, fontWeight: FontWeight.w800)),
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
              child: Image.network(url!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}