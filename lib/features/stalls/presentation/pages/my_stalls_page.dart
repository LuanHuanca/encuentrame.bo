import 'package:encuentrame/features/stalls/presentation/pages/stall_openings_page.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/api/rest_client.dart';
import 'open_stall_page.dart';
import 'stall_dashboard_page.dart';
import 'stall_form_page.dart';

class MyStallsPage extends StatefulWidget {
  const MyStallsPage({super.key});

  @override
  State<MyStallsPage> createState() => _MyStallsPageState();
}

class _MyStallsPageState extends State<MyStallsPage> {
  final _api = RestClient();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _stalls = [];

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
      final res = await _api.get('/stalls');
      final list = (res['stalls'] as List?)?.cast<dynamic>() ?? const [];
      _stalls = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on ApiClientException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StallFormPage()),
    );
    if (ok == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> stall) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StallFormPage(
          stallId: (stall['stallId'] ?? '').toString(),
          initialName: (stall['name'] ?? '').toString(),
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _close(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final name = (stall['name'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar puesto'),
        content: Text('¿Cerrar "$name" por hoy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.post('/stalls/$stallId/close', {});
      await _load();
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final name = (stall['name'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar puesto'),
        content: Text('¿Eliminar "$name"? (No se puede si está abierto)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.del('/stalls/$stallId');
      await _load();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor • Mis puestos'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _create,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Administra tus puestos: abre, cierra, edita y listo.', style: TextStyle(color: sub)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _stalls.isEmpty
                  ? Center(child: Text('No tienes puestos aún.', style: TextStyle(color: sub)))
                  : ListView.separated(
                itemCount: _stalls.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = _stalls[i];
                  final stallId = (s['stallId'] ?? '').toString();
                  final stallName = (s['name'] ?? 'Sin nombre').toString();
                  final isOpen = s['isOpen'] == true;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stallName,
                                  style: TextStyle(fontWeight: FontWeight.w800, color: title),
                                ),
                              ),
                              Chip(label: Text(isOpen ? 'ABIERTO' : 'CERRADO')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('ID: $stallId', style: TextStyle(color: sub)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StallOpeningsPage(
                                      stallId: stallId,
                                      stallName: stallName,
                                    ),
                                  ),
                                ),
                                child: const Text('Historial'),
                              ),
                              FilledButton.tonal(
                                onPressed: (!isOpen && stallId.isNotEmpty)
                                    ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OpenStallPage(
                                        stallId: stallId,
                                        stallName: stallName,
                                      ),
                                    ),
                                  );
                                  _load();
                                }
                                    : null,
                                child: const Text('Abrir hoy'),
                              ),
                              FilledButton.tonal(
                                onPressed: isOpen
                                    ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StallDashboardPage(
                                      stallId: stallId,
                                      stallName: stallName,
                                    ),
                                  ),
                                )
                                    : null,
                                child: const Text('Dashboard'),
                              ),
                              OutlinedButton(
                                onPressed: isOpen ? () => _close(s) : null,
                                child: const Text('Cerrar'),
                              ),
                              OutlinedButton(
                                onPressed: () => _edit(s),
                                child: const Text('Editar'),
                              ),
                              TextButton(
                                onPressed: () => _delete(s),
                                child: const Text('Eliminar'),
                              ),
                            ],
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