import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/dialogs/app_confirm_dialog.dart';
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

  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts(showLoader: true);
  }

  Future<void> _loadProducts({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await _api.get('/stalls/${widget.stallId}/products');
      final rawList =
          (response['products'] as List?)?.cast<dynamic>() ?? const [];

      final products = rawList
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      products.sort(
            (a, b) => (a['display'] ?? a['canonical'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
          (b['display'] ?? b['canonical'] ?? '')
              .toString()
              .toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() => _products = products);
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
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showEditProductDialog(
      Map<String, dynamic> product,
      ) async {
    final displayController = TextEditingController(
      text: (product['display'] ?? product['canonical'] ?? '').toString(),
    );

    final priceController = TextEditingController(
      text: product['price']?.toString() ?? '',
    );

    final qtyController = TextEditingController(
      text: (product['lastQty'] ?? 0).toString(),
    );

    bool isActive = product['active'] == true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('Editar producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio',
                        hintText: 'Ejemplo: 5 o 7.5',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad disponible',
                        hintText: 'Ejemplo: 10',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setLocalState(() => isActive = value);
                      },
                      title: const Text('Producto activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final display = displayController.text.trim();
                    final priceRaw = priceController.text.trim();
                    final qtyRaw = qtyController.text.trim();

                    if (display.isEmpty) {
                      AppSnackbar.error(
                        context,
                        'El nombre visible es obligatorio.',
                      );
                      return;
                    }

                    final payload = <String, dynamic>{
                      'display': display,
                      'active': isActive,
                    };

                    if (priceRaw.isNotEmpty) {
                      final price = double.tryParse(priceRaw);
                      if (price == null || price < 0) {
                        AppSnackbar.error(context, 'Precio no válido.');
                        return;
                      }
                      payload['price'] = price;
                    }

                    if (qtyRaw.isNotEmpty) {
                      final qty = int.tryParse(qtyRaw);
                      if (qty == null || qty < 0) {
                        AppSnackbar.error(context, 'Cantidad no válida.');
                        return;
                      }
                      payload['lastQty'] = qty;
                    }

                    Navigator.pop(dialogContext, payload);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    displayController.dispose();
    priceController.dispose();
    qtyController.dispose();

    return result;
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString().trim();
    if (productId.isEmpty) return;

    final payload = await _showEditProductDialog(product);
    if (payload == null) return;

    setState(() => _busy = true);

    try {
      await _api.put(
        '/stalls/${widget.stallId}/products/$productId',
        payload,
      );

      if (!mounted) return;

      AppSnackbar.success(context, 'Producto actualizado.');
      await _loadProducts(showLoader: false);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString().trim();
    if (productId.isEmpty) return;

    final nextActive = !(product['active'] == true);

    setState(() => _busy = true);

    try {
      await _api.put(
        '/stalls/${widget.stallId}/products/$productId',
        {
          'active': nextActive,
        },
      );

      if (!mounted) return;

      AppSnackbar.success(
        context,
        nextActive ? 'Producto activado.' : 'Producto desactivado.',
      );

      await _loadProducts(showLoader: false);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString().trim();
    final productName =
    (product['display'] ?? product['canonical'] ?? 'Producto').toString();

    if (productId.isEmpty) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar producto',
      message: '¿Eliminar "$productName"?',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await _api.del('/stalls/${widget.stallId}/products/$productId');

      if (!mounted) return;

      AppSnackbar.success(context, 'Producto eliminado.');
      await _loadProducts(showLoader: false);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;
      AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildEmptyState(Color titleColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: subtitleColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no tienes productos',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Abre el puesto con inventario para generar productos desde las fotos y el texto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stallName.isEmpty
              ? 'Productos'
              : 'Productos • ${widget.stallName}',
        ),
        actions: [
          IconButton(
            onPressed: (_loading || _busy)
                ? null
                : () => _loadProducts(showLoader: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.backgroundGradient(context),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
              ? _buildEmptyState(titleColor, subtitleColor)
              : ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventario actual',
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_products.length} producto${_products.length == 1 ? '' : 's'} cargado${_products.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._products.map((product) {
                final displayName =
                (product['display'] ?? product['canonical'] ?? 'Producto')
                    .toString();
                final canonical =
                (product['canonical'] ?? '').toString().trim();
                final category =
                (product['category'] ?? '').toString().trim();
                final description =
                (product['description'] ?? '').toString().trim();
                final price = product['price'];
                final qty = (product['lastQty'] ?? 0).toString();
                final isActive = product['active'] == true;
                final updatedAt =
                (product['lastSeenAt'] ?? '').toString().trim();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                if (canonical.isNotEmpty &&
                                    canonical.toLowerCase() !=
                                        displayName.toLowerCase()) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    canonical,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (isActive
                                  ? AppColors.statusOpen
                                  : subtitleColor)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.statusOpen
                                    : subtitleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (category.isNotEmpty)
                            _MetaChip(label: category),
                          _MetaChip(label: 'x$qty'),
                          if (price != null)
                            _MetaChip(label: 'Bs ${price.toString()}'),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (updatedAt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Última actualización: $updatedAt',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                              _busy ? null : () => _editProduct(product),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                              _busy ? null : () => _toggleActive(product),
                              icon: Icon(
                                isActive
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              label: Text(
                                isActive ? 'Desactivar' : 'Activar',
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
                              onPressed:
                              _busy ? null : () => _deleteProduct(product),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                Theme.of(context).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
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