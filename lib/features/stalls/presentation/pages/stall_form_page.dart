import 'package:flutter/material.dart';

import '../../../../shared/api/rest_client.dart';

class StallFormPage extends StatefulWidget {
  const StallFormPage({super.key, this.stallId, this.initialName});

  final String? stallId;
  final String? initialName;

  @override
  State<StallFormPage> createState() => _StallFormPageState();
}

class _StallFormPageState extends State<StallFormPage> {
  final _api = RestClient();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _error = 'Nombre requerido');
        return;
      }

      if (widget.stallId == null) {
        await _api.post('/stalls', {'name': name});
      } else {
        await _api.put('/stalls/${widget.stallId}', {'name': name});
      }

      if (mounted) Navigator.pop(context, true);
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.stallId == null ? 'Crear puesto' : 'Editar puesto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del puesto'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: Text(_loading ? 'Guardando...' : 'Guardar'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}