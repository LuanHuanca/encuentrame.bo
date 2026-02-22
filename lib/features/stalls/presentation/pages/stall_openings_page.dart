import 'package:amplify_flutter/amplify_flutter.dart';
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get(
        '/stalls/${widget.stallId}/openings',
        queryParameters: {'limit': '50'},
      );

      // Aceptar 'openings', 'items' o 'data' como lista
      List<dynamic> rawList = const [];
      if (res['openings'] is List) {
        rawList = (res['openings'] as List).toList();
      } else if (res['items'] is List) {
        rawList = (res['items'] as List).toList();
      } else if (res['data'] is List) {
        rawList = (res['data'] as List).toList();
      }

      _openings = rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on ApiClientException catch (e) {
      _error = e.message;
    } catch (e, st) {
      _error = e.toString();
      debugPrint('StallOpeningsPage _load error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 56, color: sub),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: sub, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _openings.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 56, color: sub),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay aperturas',
                      style: TextStyle(color: sub, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuando abras y cierres tu puesto, aquí aparecerá el historial.',
                      style: TextStyle(color: sub, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Actualizar'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _openings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final o = _openings[i];
                  final status = (o['status'] ?? '').toString().toUpperCase();
                  final isOpen = status == 'OPEN';
                  final openedAt = _fmtDate(o['openedAt']?.toString());
                  final closedAt = _fmtDate(o['closedAt']?.toString());

                  return _OpeningCard(
                    opening: o,
                    stallId: widget.stallId,
                    stallName: widget.stallName,
                    openedAt: openedAt,
                    closedAt: closedAt,
                    isOpen: isOpen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StallOpeningDetailPage(
                          stallId: widget.stallId,
                          stallName: widget.stallName,
                          opening: o,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({
    required this.opening,
    required this.stallId,
    required this.stallName,
    required this.openedAt,
    required this.closedAt,
    required this.isOpen,
    required this.onTap,
  });

  final Map<String, dynamic> opening;
  final String stallId;
  final String stallName;
  final String openedAt;
  final String closedAt;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);
    final photoKey = opening['stallPhotoKey'] ?? opening['productsPhotoKey'];
    final photoKeyStr = photoKey is String ? photoKey : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isOpen ? AppColors.statusOpen : AppColors.statusClosed)
              .withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Thumbnail(photoKey: photoKeyStr, isOpen: isOpen),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        openedAt.isEmpty ? 'Apertura' : openedAt,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: title,
                        ),
                      ),
                      if (closedAt.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Cerrado: $closedAt',
                          style: TextStyle(fontSize: 13, color: sub),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? AppColors.statusOpen.withValues(alpha: 0.15)
                                  : AppColors.statusClosed.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOpen ? 'Abierto' : 'Cerrado',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOpen
                                    ? AppColors.statusOpen
                                    : AppColors.statusClosed,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Ver detalle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({this.photoKey, required this.isOpen});

  final String? photoKey;
  final bool isOpen;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  String? _url;

  @override
  void initState() {
    super.initState();
    if (widget.photoKey != null) _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final res = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(widget.photoKey!),
      ).result;
      if (mounted) setState(() => _url = res.url.toString());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 100,
      color: (widget.isOpen ? AppColors.statusOpen : AppColors.statusClosed)
          .withValues(alpha: 0.12),
      child: _url != null
          ? Image.network(
              _url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        widget.isOpen ? Icons.storefront_rounded : Icons.history_rounded,
        size: 36,
        color: (widget.isOpen ? AppColors.statusOpen : AppColors.statusClosed)
            .withValues(alpha: 0.6),
      ),
    );
  }
}
