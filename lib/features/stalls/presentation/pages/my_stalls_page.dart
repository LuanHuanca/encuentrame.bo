import 'package:flutter/material.dart';

import '../../../../app/shell/main_shell.dart';
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

  Map<String, dynamic>? _stall;
  int _backendStallCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStall(showLoader: true);
  }

  Future<void> _loadStall({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await _api.get('/stalls');
      final rawList = (response['stalls'] as List?)?.cast<dynamic>() ?? const [];

      final stalls = rawList
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;

      setState(() {
        _backendStallCount = stalls.length;
        _stall = stalls.isEmpty ? null : stalls.first;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromApiError(error),
        );
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromGenericError(error),
        );
      }
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createStall() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StallFormPage()),
    );

    if (created == true) {
      await _loadStall(showLoader: true);
    }
  }

  Future<void> _editStallName(Map<String, dynamic> stall) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StallFormPage(
          stallId: (stall['stallId'] ?? '').toString(),
          initialName: (stall['name'] ?? '').toString(),
        ),
      ),
    );

    if (updated == true) {
      await _loadStall(showLoader: true);
    }
  }

  Future<void> _openOrViewDashboard(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Mi puesto').toString();
    final isOpen = stall['isOpen'] == true;

    if (stallId.isEmpty) return;

    if (isOpen) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StallDashboardPage(
            stallId: stallId,
            stallName: stallName,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpenStallPage(
            stallId: stallId,
            stallName: stallName,
          ),
        ),
      );
    }

    if (!mounted) return;

    await _loadStall(showLoader: true);
  }

  Future<void> _closeStall(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Mi puesto').toString();

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cerrar puesto',
      message:
      '¿Cerrar "$stallName"? Después podrás volver a abrirlo cuando quieras.',
      confirmLabel: 'Cerrar',
      cancelLabel: 'Cancelar',
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await _api.post('/stalls/$stallId/close', {});

      if (!mounted) return;

      AppSnackbar.success(context, 'Puesto cerrado.');
      await _loadStall(showLoader: false);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromApiError(error),
        );
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromGenericError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteStall(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Mi puesto').toString();

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar puesto',
      message:
      '¿Eliminar "$stallName"? Para eliminarlo, antes debe estar cerrado.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await _api.del('/stalls/$stallId');

      if (!mounted) return;

      AppSnackbar.success(context, 'Puesto eliminado.');

      setState(() {
        _stall = null;
        _backendStallCount = 0;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromApiError(error),
        );
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(
          context,
          UserFriendlyMessages.fromGenericError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi puesto'),
        actions: [
          IconButton(
            onPressed: shell == null ? null : shell.switchToBuyer,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Cambiar a comprador',
          ),
          IconButton(
            onPressed: (_loading || _busy)
                ? null
                : () => _loadStall(showLoader: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: _stall == null
          ? FloatingActionButton.extended(
        onPressed: (_loading || _busy) ? null : _createStall,
        icon: const Icon(Icons.add),
        label: const Text('Crear puesto'),
      )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _loadStall(showLoader: false),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'Publica tu ubicación actual para que los compradores te encuentren.',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              if (_backendStallCount > 1) ...[
                _InfoBanner(
                  message:
                  'Se detectaron varios puestos en backend. Este MVP solo usa el primero.',
                ),
                const SizedBox(height: 12),
              ],
              if (_stall == null)
                _EmptyState(
                  subtitleColor: subtitleColor,
                  onCreate: _busy ? null : _createStall,
                )
              else
                _SingleStallCard(
                  stall: _stall!,
                  busy: _busy,
                  onPrimary: () => _openOrViewDashboard(_stall!),
                  onEdit: () => _editStallName(_stall!),
                  onClose: _stall!['isOpen'] == true
                      ? () => _closeStall(_stall!)
                      : null,
                  onDelete: () => _deleteStall(_stall!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeBright.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.subtitleColor,
    required this.onCreate,
  });

  final Color subtitleColor;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 56),
          Icon(
            Icons.storefront_outlined,
            size: 64,
            color: subtitleColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Todavía no tienes un puesto',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea uno para poder publicar tu ubicación, fotos e inventario.',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
            ),
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
    );
  }
}

class _SingleStallCard extends StatelessWidget {
  const _SingleStallCard({
    required this.stall,
    required this.busy,
    required this.onPrimary,
    required this.onEdit,
    required this.onClose,
    required this.onDelete,
  });

  final Map<String, dynamic> stall;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback onEdit;
  final VoidCallback? onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    final stallName = (stall['name'] ?? 'Mi puesto').toString();
    final isOpen = stall['isOpen'] == true;
    final addressLabel =
    (stall['currentAddressLabel'] ?? '').toString().trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stallName,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    isOpen ? 'Abierto' : 'Cerrado',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: isOpen
                      ? AppColors.statusOpen.withValues(alpha: 0.16)
                      : subtitleColor.withValues(alpha: 0.12),
                ),
              ],
            ),
            if (addressLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: subtitleColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      addressLabel,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onPrimary,
                    icon: Icon(
                      isOpen
                          ? Icons.dashboard_outlined
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      isOpen ? 'Ver panel' : 'Abrir puesto',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar nombre'),
                  ),
                ),
              ],
            ),
            if (isOpen && onClose != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onClose,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Cerrar puesto'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}