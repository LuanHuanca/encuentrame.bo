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
      final rawList = (response['products'] as List?)?.cast<dynamic>() ?? const [];

      _products = rawList
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      _products.sort(
            (a, b) => (a['display'] ?? a['canonical'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
          (b['display'] ?? b['canonical'] ?? '').toString().toLowerCase(),
        ),
      );
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

  Future<Map<String, dynamic>?> _showProductDialog({
    Map<String, dynamic>? product,
  }) async {
    final isEdit = product != null;

    final nameController = TextEditingController(
      text: (product?['display'] ?? product?['canonical'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (product?['category'] ?? '').toString(),
    );
    final descriptionController = TextEditingController(
      text: (product?['description'] ?? '').toString(),
    );
    final priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final qtyController = TextEditingController(
      text: (product?['lastQty'] ?? 1).toString(),
    );

    bool isActive = product?['active'] == true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            return AlertDialog(
              title: Text(isEdit ? 'Editar producto' : 'Nuevo producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio (opcional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                      ),
                    ),
                    if (isEdit) ...[
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
                    final display = nameController.text.trim();
                    final category = categoryController.text.trim();
                    final description = descriptionController.text.trim();
                    final price = double.tryParse(priceController.text.trim());
                    final qty = int.tryParse(qtyController.text.trim());

                    if (display.isEmpty) {
                      AppSnackbar.error(context, 'El nombre es obligatorio.');
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      <String, dynamic>{
                        'display': display,
                        'canonical': display.toLowerCase(),
                        'category': category.isEmpty ? null : category,
                        'description':
                        description.isEmpty ? null : description,
                        if (price != null) 'price': price,
                        if (qty != null) 'lastQty': qty,
                        if (isEdit) 'active': isActive,
                      },
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    qtyController.dispose();

    return result;
  }

  Future<void> _createProduct() async {
    final payload = await _showProductDialog();
    if (payload == null) return;

    setState(() => _busy = true);

    try {
      await _api.post('/stalls/${widget.stallId}/products', payload);

      if (!mounted) return;

      AppSnackbar.success(context, 'Producto creado.');
      await _loadProducts(showLoader: false);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString();
    if (productId.isEmpty) return;

    final payload = await _showProductDialog(product: product);
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

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString();
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

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromApiError(error));
      }
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (mounted) {
        AppSnackbar.error(context, UserFriendlyMessages.fromGenericError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createProduct,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _products.isEmpty
            ? Center(
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
                'Crea productos manualmente o abre el puesto con inventario para generarlos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtitleColor),
              ),
            ],
          ),
        )
            : ListView.separated(
          itemCount: _products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final product = _products[index];
            final displayName =
            (product['display'] ?? product['canonical'] ?? 'Producto')
                .toString();
            final category =
            (product['category'] ?? '').toString().trim();
            final description =
            (product['description'] ?? '').toString().trim();
            final price = product['price'];
            final qty = (product['lastQty'] ?? 0).toString();
            final isActive = product['active'] == true;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppThemeColors.inputFill(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(isActive ? 'Activo' : 'Inactivo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (category.isNotEmpty) Chip(label: Text(category)),
                      Chip(label: Text('x$qty')),
                      if (price != null)
                        Chip(label: Text('Bs ${price.toString()}')),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(color: subtitleColor),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _editProduct(product),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _deleteProduct(product),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
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
          },
        ),
      ),
    );
  }
}