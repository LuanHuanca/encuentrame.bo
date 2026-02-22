import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/api/rest_client.dart';

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
  final _api = RestClient();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
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
      _error = e.message;
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final productId = (p['productId'] ?? '').toString();
    if (productId.isEmpty) return;

    final displayCtrl = TextEditingController(text: (p['display'] ?? '').toString());
    final priceCtrl = TextEditingController(text: (p['price'] ?? '').toString());
    bool active = p['active'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: displayCtrl, decoration: const InputDecoration(labelText: 'Nombre visible')),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Precio (opcional)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: active,
              onChanged: (v) => active = v,
              title: const Text('Activo'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) {
      displayCtrl.dispose();
      priceCtrl.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'display': displayCtrl.text.trim().isEmpty ? null : displayCtrl.text.trim(),
      'active': active,
    };

    final price = double.tryParse(priceCtrl.text.trim());
    if (price != null) payload['price'] = price;

    displayCtrl.dispose();
    priceCtrl.dispose();

    setState(() => _loading = true);
    try {
      await _api.put('/stalls/${widget.stallId}/products/$productId', payload);
      await _load();
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Productos • ${widget.stallName}'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _products.isEmpty
            ? Center(child: Text('Aún no hay productos en catálogo.', style: TextStyle(color: sub)))
            : ListView.separated(
          itemCount: _products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final p = _products[i];
            final display = (p['display'] ?? p['canonical'] ?? 'Producto').toString();
            final canonical = (p['canonical'] ?? '').toString();
            final lastQty = p['lastQty']?.toString();
            final lastSeenAt = (p['lastSeenAt'] ?? '').toString();
            final active = p['active'] == true;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(display, style: TextStyle(color: t, fontWeight: FontWeight.w800))),
                        Chip(label: Text(active ? 'ACTIVO' : 'INACTIVO')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (canonical.isNotEmpty) Text('canonical: $canonical', style: TextStyle(color: sub)),
                    if (lastQty != null) Text('última qty: $lastQty', style: TextStyle(color: sub)),
                    if (lastSeenAt.isNotEmpty) Text('última vez: $lastSeenAt', style: TextStyle(color: sub)),
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
    );
  }
}