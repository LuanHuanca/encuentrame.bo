import 'package:amplify_flutter/amplify_flutter.dart';
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
import 'stall_products_page.dart';

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

  String? _mainPhotoUrl;
  String? _coverPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadStall(showLoader: true);
  }

  Future<String?> _getStorageUrl(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(trimmed),
      ).result;

      return response.url.toString();
    } catch (_) {
      return null;
    }
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

      final firstStall = stalls.isEmpty ? null : stalls.first;

      String? mainPhotoUrl;
      String? coverPhotoUrl;

      if (firstStall != null) {
        final mainPhotoKey = (firstStall['mainPhotoKey'] ?? '').toString().trim();
        final coverPhotoKey = (firstStall['coverPhotoKey'] ?? '').toString().trim();

        if (mainPhotoKey.isNotEmpty) {
          mainPhotoUrl = await _getStorageUrl(mainPhotoKey);
        }

        if (coverPhotoKey.isNotEmpty) {
          coverPhotoUrl = await _getStorageUrl(coverPhotoKey);
        }
      }

      if (!mounted) return;

      setState(() {
        _backendStallCount = stalls.length;
        _stall = firstStall;
        _mainPhotoUrl = mainPhotoUrl;
        _coverPhotoUrl = coverPhotoUrl;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
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
      MaterialPageRoute(
        builder: (_) => const StallFormPage(),
      ),
    );

    if (created == true) {
      await _loadStall(showLoader: true);
    }
  }

  Future<void> _editStall(Map<String, dynamic> stall) async {
    final paymentMethodsDynamic =
        (stall['paymentMethods'] as List?)?.cast<dynamic>() ?? const [];
    final scheduleDynamic =
        (stall['schedule'] as List?)?.cast<dynamic>() ?? const [];

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StallFormPage(
          stallId: (stall['stallId'] ?? '').toString(),
          initialName: (stall['name'] ?? '').toString(),
          initialCategory: (stall['category'] ?? '').toString(),
          initialDescription: (stall['description'] ?? '').toString(),
          initialMainPhotoKey: (stall['mainPhotoKey'] ?? '').toString(),
          initialCoverPhotoKey: (stall['coverPhotoKey'] ?? '').toString(),
          initialPaymentMethods:
          paymentMethodsDynamic.map((e) => e.toString()).toList(),
          initialPriceRange: (stall['priceRange'] ?? '').toString(),
          initialReferenceText: (stall['referenceText'] ?? '').toString(),
          initialSchedule: scheduleDynamic
              .map((item) => Map<String, dynamic>.from(
            (item as Map).cast<String, dynamic>(),
          ))
              .toList(),
          initialLocationVisibility:
          (stall['locationVisibility'] ?? '').toString(),
          initialActive: stall['active'] == true,
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

  Future<void> _manageProducts(Map<String, dynamic> stall) async {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Mi puesto').toString();

    if (stallId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StallProductsPage(
          stallId: stallId,
          stallName: stallName,
        ),
      ),
    );

    if (!mounted) return;
    await _loadStall(showLoader: false);
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
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
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
        _mainPhotoUrl = null;
        _coverPhotoUrl = null;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
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
                'Configura tu puesto, publica tu ubicación actual y gestiona productos desde un solo lugar.',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              if (_backendStallCount > 1) ...[
                const _InfoBanner(
                  message:
                  'Se detectaron varios puestos en backend. Este MVP sigue usando el primero.',
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
                  mainPhotoUrl: _mainPhotoUrl,
                  coverPhotoUrl: _coverPhotoUrl,
                  onPrimary: () => _openOrViewDashboard(_stall!),
                  onEdit: () => _editStall(_stall!),
                  onProducts: () => _manageProducts(_stall!),
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
            'Crea uno para publicar ubicación, horarios, referencias, métodos de pago y productos.',
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
    required this.mainPhotoUrl,
    required this.coverPhotoUrl,
    required this.onPrimary,
    required this.onEdit,
    required this.onProducts,
    required this.onClose,
    required this.onDelete,
  });

  final Map<String, dynamic> stall;
  final bool busy;
  final String? mainPhotoUrl;
  final String? coverPhotoUrl;
  final VoidCallback onPrimary;
  final VoidCallback onEdit;
  final VoidCallback onProducts;
  final VoidCallback? onClose;
  final VoidCallback onDelete;

  String _formatPriceRange(String value) {
    switch (value.trim()) {
      case 'economic':
        return 'Económico';
      case 'medium':
        return 'Medio';
      case 'premium':
        return 'Premium';
      default:
        return value.trim();
    }
  }

  String _formatLocationVisibility(String value) {
    switch (value.trim()) {
      case 'exact':
        return 'Ubicación exacta';
      case 'approximate':
        return 'Ubicación aproximada';
      default:
        return value.trim();
    }
  }

  String _formatPaymentMethod(String value) {
    switch (value.trim()) {
      case 'cash':
        return 'Efectivo';
      case 'qr':
        return 'QR';
      case 'transfer':
        return 'Transferencia';
      default:
        return value.trim();
    }
  }

  int _scheduleCount(List<dynamic> schedule) {
    return schedule.whereType<Map>().length;
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    final stallName = (stall['name'] ?? 'Mi puesto').toString();
    final category = (stall['category'] ?? '').toString().trim();
    final description = (stall['description'] ?? '').toString().trim();
    final referenceText = (stall['referenceText'] ?? '').toString().trim();
    final isOpen = stall['isOpen'] == true;
    final isActive = stall['active'] != false;
    final addressLabel = (stall['currentAddressLabel'] ?? '').toString().trim();
    final priceRange = (stall['priceRange'] ?? '').toString().trim();
    final locationVisibility =
    (stall['locationVisibility'] ?? '').toString().trim();
    final paymentMethods =
        (stall['paymentMethods'] as List?)?.cast<dynamic>() ?? const [];
    final schedule = (stall['schedule'] as List?)?.cast<dynamic>() ?? const [];

    final heroImage = coverPhotoUrl ?? mainPhotoUrl;
    final initials =
    stallName.trim().isEmpty ? 'P' : stallName.trim()[0].toUpperCase();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heroImage != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Image.network(
                heroImage,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 150,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.blueNeon],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Padding(
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(
                      label: isOpen ? 'Abierto' : 'Cerrado',
                      active: isOpen,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (category.isNotEmpty) _MetaChip(label: category),
                    _MetaChip(label: isActive ? 'Activo' : 'Inactivo'),
                    if (priceRange.isNotEmpty)
                      _MetaChip(label: _formatPriceRange(priceRange)),
                    if (locationVisibility.isNotEmpty)
                      _MetaChip(
                        label: _formatLocationVisibility(locationVisibility),
                      ),
                    if (_scheduleCount(schedule) > 0)
                      _MetaChip(label: '${_scheduleCount(schedule)} días'),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (referenceText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    text: referenceText,
                    color: subtitleColor,
                  ),
                ],
                if (addressLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    text: addressLabel,
                    color: subtitleColor,
                  ),
                ],
                if (paymentMethods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: paymentMethods
                        .map((item) => _MetaChip(
                      label: _formatPaymentMethod(item.toString()),
                    ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),
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
                        label: Text(isOpen ? 'Ver panel' : 'Abrir puesto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onProducts,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Productos'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
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
                          foregroundColor:
                          Theme.of(context).colorScheme.error,
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
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: subtitleColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.statusOpen : AppColors.statusClosed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}