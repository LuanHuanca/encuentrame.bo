import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/dialogs/app_confirm_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'open_stall_page.dart';
import 'stall_dashboard_page.dart';
import 'stall_form_page.dart';

class MyStallsPage extends StatefulWidget {
  const MyStallsPage({super.key});

  @override
  State<MyStallsPage> createState() => _MyStallsPageState();
}

class _MyStallsPageState extends State<MyStallsPage> {
  final RestClient _api = RestClient();

  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _stalls = [];

  @override
  void initState() {
    super.initState();
    _load(showLoader: true);
  }

  Future<void> _load({required bool showLoader}) async {
    if (showLoader && mounted) setState(() => _loading = true);

    try {
      final res = await _api.get('/stalls');
      final list = (res['stalls'] as List?)?.cast<dynamic>() ?? const [];
      final mapped = list.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() => _stalls = mapped);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StallFormPage()),
    );
    if (ok == true) _load(showLoader: true);
  }

  Future<void> _editName(Map<String, dynamic> stall) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StallFormPage(
          stallId: (stall['stallId'] ?? '').toString(),
          initialName: (stall['name'] ?? '').toString(),
        ),
      ),
    );
    if (ok == true) _load(showLoader: true);
  }

  Future<void> _closeStall(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final name = (stall['name'] ?? 'Mi puesto').toString();

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Cerrar puesto',
      message: '¿Cerrar "$name"? Podrás volver a abrir cuando quieras.',
      confirmLabel: 'Cerrar',
      cancelLabel: 'Cancelar',
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _api.post('/stalls/$stallId/close', {});
      if (!mounted) return;
      AppSnackbar.success(context, 'Puesto cerrado.');
      await _load(showLoader: false);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteStall(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final name = (stall['name'] ?? 'Sin nombre').toString();

    final ok = await AppConfirmDialog.show(
      context,
      title: 'Eliminar puesto',
      message: '¿Eliminar "$name"? Esta acción no se puede deshacer.\n\nPara eliminarlo, el puesto debe estar cerrado.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _api.del('/stalls/$stallId');
      if (!mounted) return;
      AppSnackbar.success(context, 'Puesto eliminado.');
      await _load(showLoader: false);
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromApiError(e));
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (mounted) AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFlow(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Mi puesto').toString();
    final isOpen = stall['isOpen'] == true;

    if (stallId.isEmpty) return;

    if (isOpen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StallDashboardPage(stallId: stallId, stallName: stallName),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenStallPage(stallId: stallId, stallName: stallName),
      ),
    );

    if (!mounted) return;
    _load(showLoader: true);
  }

  void _showActions(Map<String, dynamic> stall) {
    final stallName = (stall['name'] ?? 'Sin nombre').toString();
    final isOpen = stall['isOpen'] == true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    stallName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(isOpen ? Icons.dashboard_outlined : Icons.play_circle_outline),
                  title: Text(isOpen ? 'Ir al panel' : 'Abrir puesto'),
                  subtitle: Text(isOpen ? 'Ver productos, ubicación y cerrar.' : 'Ubicación + 2 fotos + inventario.'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFlow(stall);
                  },
                ),
                if (isOpen) ...[
                  ListTile(
                    leading: Icon(Icons.stop_circle_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text('Cerrar puesto', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    onTap: _busy
                        ? null
                        : () {
                      Navigator.pop(ctx);
                      _closeStall(stall);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar nombre'),
                  onTap: _busy
                      ? null
                      : () {
                    Navigator.pop(ctx);
                    _editName(stall);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text('Eliminar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: _busy
                      ? null
                      : () {
                    Navigator.pop(ctx);
                    _deleteStall(stall);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis puestos'),
        actions: [
          IconButton(
            onPressed: (_loading || _busy) ? null : () => _load(showLoader: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_loading || _busy) ? null : _create,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showLoader: false),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crea, abre y gestiona tus puestos.',
                style: TextStyle(color: sub, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _stalls.isEmpty
                    ? _EmptyState(subtitleColor: sub, onCreate: _busy ? null : _create)
                    : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _stalls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final stall = _stalls[i];
                    return _StallCard(
                      stall: stall,
                      busy: _busy,
                      onPrimary: () => _openFlow(stall),
                      onMore: () => _showActions(stall),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.subtitleColor, required this.onCreate});

  final Color subtitleColor;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: subtitleColor),
            const SizedBox(height: 14),
            Text(
              'Aún no tienes puestos',
              style: TextStyle(
                color: AppThemeColors.titleColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea uno para empezar a vender con ubicación, fotos e inventario.',
              style: TextStyle(color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Crear puesto'),
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
    required this.busy,
    required this.onPrimary,
    required this.onMore,
  });

  final Map<String, dynamic> stall;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);

    final stallName = (stall['name'] ?? 'Sin nombre').toString();
    final isOpen = stall['isOpen'] == true;
    final address = (stall['currentAddressLabel'] ?? '').toString().trim();

    final primaryLabel = isOpen ? 'Panel' : 'Abrir';
    final primaryIcon = isOpen ? Icons.dashboard_outlined : Icons.play_arrow;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stallName,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  label: Text(isOpen ? 'Abierto' : 'Cerrado', style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: isOpen
                      ? AppColors.statusOpen.withValues(alpha: 0.15)
                      : sub.withValues(alpha: 0.12),
                ),
              ],
            ),
            if (isOpen && address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: sub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(color: sub, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : onPrimary,
                    icon: Icon(primaryIcon),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: busy ? null : onMore,
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: 'Acciones',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}