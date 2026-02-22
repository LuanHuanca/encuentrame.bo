import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/dialogs/app_confirm_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'open_stall_page.dart';
import 'stall_dashboard_page.dart';
import 'stall_form_page.dart';
import 'stall_openings_page.dart';
import 'stall_products_page.dart';

class MyStallsPage extends StatefulWidget {
  const MyStallsPage({super.key});

  @override
  State<MyStallsPage> createState() => _MyStallsPageState();
}

class _MyStallsPageState extends State<MyStallsPage> {
  final _api = RestClient();

  bool _loading = false;
  List<Map<String, dynamic>> _stalls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final res = await _api.get('/stalls');
      final list = (res['stalls'] as List?)?.cast<dynamic>() ?? const [];
      _stalls = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
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

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Cerrar puesto',
      message: '¿Cerrar "$name" por hoy? No podrás reabrir hasta mañana.',
      confirmLabel: 'Cerrar',
      cancelLabel: 'Cancelar',
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.post('/stalls/$stallId/close', {});
      if (mounted)
        AppSnackbar.success(context, 'Puesto cerrado correctamente.');
      await _load();
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showStallActions(BuildContext context, Map<String, dynamic> stall) {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Sin nombre').toString();
    final isOpen = stall['isOpen'] == true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text(
                  stallName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: const Text('Abrir hoy'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isOpen && stallId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OpenStallPage(
                                stallId: stallId,
                                stallName: stallName,
                              ),
                            ),
                          ).then((_) => _load());
                        }
                      },
                      enabled: !isOpen && stallId.isNotEmpty,
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Historial'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StallOpeningsPage(
                              stallId: stallId,
                              stallName: stallName,
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('Productos'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StallProductsPage(
                              stallId: stallId,
                              stallName: stallName,
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined),
                      title: Text(isOpen ? 'Dashboard' : 'Ver último'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => isOpen
                                ? StallDashboardPage(
                                    stallId: stallId,
                                    stallName: stallName,
                                  )
                                : StallOpeningsPage(
                                    stallId: stallId,
                                    stallName: stallName,
                                  ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.stop_circle_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Cerrar puesto',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: isOpen
                          ? () {
                              Navigator.pop(ctx);
                              _close(stall);
                            }
                          : null,
                      enabled: isOpen,
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _edit(stall);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _delete(stall);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final name = (stall['name'] ?? 'Sin nombre').toString();

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Eliminar puesto',
      message:
          '¿Eliminar "$name"? Esta acción no se puede deshacer. El puesto debe estar cerrado.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _api.del('/stalls/$stallId');
      if (mounted) AppSnackbar.success(context, 'Puesto eliminado.');
      await _load();
    } on ApiClientException catch (e) {
      UserFriendlyMessages.logToConsole(e);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      if (mounted)
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis puestos'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
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
                  Text(
                    'Toca un puesto para gestionarlo.',
                    style: TextStyle(color: sub, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _stalls.isEmpty
                        ? Center(
                            child: Text(
                              'No tienes puestos aún.',
                              style: TextStyle(color: sub),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _stalls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final s = _stalls[i];
                              return _StallCard(
                                stall: s,
                                onManage: () => _showStallActions(context, s),
                                loading: _loading,
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

class _StallCard extends StatelessWidget {
  const _StallCard({
    required this.stall,
    required this.onManage,
    required this.loading,
  });

  final Map<String, dynamic> stall;
  final VoidCallback onManage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);
    final stallName = (stall['name'] ?? 'Sin nombre').toString();
    final isOpen = stall['isOpen'] == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: loading ? null : onManage,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stallName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        isOpen ? 'Abierto' : 'Cerrado',
                        style: const TextStyle(fontSize: 12),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: isOpen
                          ? AppColors.orangeBright.withValues(alpha: 0.15)
                          : sub.withValues(alpha: 0.15),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
