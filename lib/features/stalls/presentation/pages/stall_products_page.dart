import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class StallProductsPage extends StatefulWidget {
  const StallProductsPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<StallProductsPage> createState() => _StallProductsPageState();
}

class _StallProductsPageState extends State<StallProductsPage> {
  final RestClient _api = RestClient();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/stalls/${widget.stallId}/products');
      final list = (res['products'] as List?)?.cast<dynamic>() ?? const [];
      _products = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
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

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _products;

    return _products.where((p) {
      final display = (p['display'] ?? '').toString().toLowerCase();
      final canonical = (p['canonical'] ?? '').toString().toLowerCase();
      return display.contains(q) || canonical.contains(q);
    }).toList();
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final productId = (p['productId'] ?? '').toString();
    if (productId.isEmpty) return;

    final displayCtrl = TextEditingController(
      text: (p['display'] ?? '').toString(),
    );
    final priceCtrl = TextEditingController(
      text: (p['price'] ?? '').toString(),
    );
    bool active = p['active'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Editar producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: displayCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre visible'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Precio (opcional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      displayCtrl.dispose();
      priceCtrl.dispose();
      return;
    }

    final payload = <String, dynamic>{};
    final display = displayCtrl.text.trim();
    if (display.isNotEmpty) payload['display'] = display;
    payload['active'] = active;

    final priceText = priceCtrl.text.trim();
    if (priceText.isNotEmpty) {
      final price = double.tryParse(priceText);
      if (price != null) payload['price'] = price;
    }

    displayCtrl.dispose();
    priceCtrl.dispose();

    setState(() => _loading = true);
    try {
      await _api.put('/stalls/${widget.stallId}/products/$productId', payload);
      if (mounted) AppSnackbar.success(context, 'Producto actualizado.');
      await _load();
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
      }
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);
    final data = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: Text('Productos • ${widget.stallName}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
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
              ],
            ),
          ),
        )
            : Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar producto…',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: data.isEmpty
                  ? Center(
                child: Text(
                  'No hay productos para mostrar.',
                  style: TextStyle(color: sub),
                ),
              )
                  : ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, _) =>
                const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = data[i];
                  final display = (p['display'] ??
                      p['canonical'] ??
                      'Producto')
                      .toString();
                  final canonical = (p['canonical'] ?? '').toString();
                  final active = p['active'] == true;
                  final price = p['price'];

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  display,
                                  style: TextStyle(
                                    color: t,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  active ? 'ACTIVO' : 'INACTIVO',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (canonical.isNotEmpty)
                            Text(
                              'Nombre interno: $canonical',
                              style: TextStyle(color: sub),
                            ),
                          if (price != null)
                            Text(
                              'Precio: $price',
                              style: TextStyle(color: sub),
                            ),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () => _edit(p),
                            child: const Text('Editar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}