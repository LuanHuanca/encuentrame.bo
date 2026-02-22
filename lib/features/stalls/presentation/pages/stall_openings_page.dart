import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/api/rest_client.dart';
import 'stall_opening_detail_page.dart';

class StallOpeningsPage extends StatefulWidget {
  const StallOpeningsPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<StallOpeningsPage> createState() => _StallOpeningsPageState();
}

class _StallOpeningsPageState extends State<StallOpeningsPage> {
  final _api = RestClient();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _openings = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/stalls/${widget.stallId}/openings', queryParameters: {
        'limit': '50',
      });

      final list = (res['openings'] as List?)?.cast<dynamic>() ?? const [];
      _openings = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on ApiClientException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error: $e';
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
        title: Text('Historial • ${widget.stallName}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _openings.isEmpty
            ? Center(child: Text('Aún no hay aperturas.', style: TextStyle(color: sub)))
            : ListView.separated(
          itemCount: _openings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final o = _openings[i];

            final status = (o['status'] ?? '').toString();
            final openedAt = _fmtDate(o['openedAt']?.toString());
            final closedAt = _fmtDate(o['closedAt']?.toString());

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
                            openedAt.isEmpty ? 'Apertura' : openedAt,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: title,
                            ),
                          ),
                        ),
                        Chip(label: Text(status.isEmpty ? '—' : status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (closedAt.isNotEmpty)
                      Text('Cerrado: $closedAt', style: TextStyle(color: sub)),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StallOpeningDetailPage(
                            stallId: widget.stallId,
                            stallName: widget.stallName,
                            opening: o,
                          ),
                        ),
                      ),
                      child: const Text('Ver detalle'),
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