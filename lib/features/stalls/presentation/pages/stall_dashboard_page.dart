import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/dialogs/app_confirm_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class StallDashboardPage extends StatefulWidget {
  const StallDashboardPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<StallDashboardPage> createState() => _StallDashboardPageState();
}

class _StallDashboardPageState extends State<StallDashboardPage> {
  final RestClient _api = RestClient();

  bool _loading = true;
  bool _productsLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _stall;
  Map<String, dynamic>? _opening;

  String? _stallPhotoUrl;
  String? _productsPhotoUrl;

  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';

    try {
      final date = DateTime.parse(iso).toLocal();

      String twoDigits(int value) => value.toString().padLeft(2, '0');

      return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
          '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Future<String?> _getStorageUrl(String key) async {
    try {
      final response = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(key),
      ).result;

      return response.url.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get('/stalls/${widget.stallId}/current');

      _stall = (response['stall'] as Map?)?.cast<String, dynamic>();
      _opening = (response['opening'] as Map?)?.cast<String, dynamic>();

      final stallPhotoKey = _opening?['stallPhotoKey'] as String?;
      final productsPhotoKey = _opening?['productsPhotoKey'] as String?;

      _stallPhotoUrl = stallPhotoKey == null
          ? null
          : await _getStorageUrl(stallPhotoKey);

      _productsPhotoUrl = productsPhotoKey == null
          ? null
          : await _getStorageUrl(productsPhotoKey);

      await _loadProducts(showLoader: true);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      _errorMessage = UserFriendlyMessages.fromApiError(error);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      _errorMessage = UserFriendlyMessages.fromGenericError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadProducts({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() => _productsLoading = true);
    }

    try {
      final response = await _api.get('/stalls/${widget.stallId}/products');
      final rawList =
          (response['products'] as List?)?.cast<dynamic>() ?? const [];

      _products = rawList
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
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
        setState(() => _productsLoading = false);
      }
    }
  }

  Future<void> _closeStall() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cerrar puesto',
      message: '¿Cerrar tu puesto ahora?',
      confirmLabel: 'Cerrar',
      cancelLabel: 'Cancelar',
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      await _api.post('/stalls/${widget.stallId}/close', {});

      if (!mounted) return;

      AppSnackbar.success(context, 'Puesto cerrado.');
      Navigator.pop(context);
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final productId = (product['productId'] ?? '').toString();

    if (productId.isEmpty) return;

    final nameController = TextEditingController(
      text: (product['display'] ?? product['canonical'] ?? '').toString(),
    );

    final quantityController = TextEditingController(
      text: (product['lastQty'] ?? 1).toString(),
    );

    bool isActive = product['active'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            return AlertDialog(
              title: const Text('Editar producto'),
              content: Column(
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
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                    ),
                    keyboardType: TextInputType.number,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      nameController.dispose();
      quantityController.dispose();
      return;
    }

    final displayName = nameController.text.trim();
    final lastQuantity = int.tryParse(quantityController.text.trim());

    nameController.dispose();
    quantityController.dispose();

    final payload = <String, dynamic>{
      'active': isActive,
    };

    if (displayName.isNotEmpty) {
      payload['display'] = displayName;
    }

    if (lastQuantity != null) {
      payload['lastQty'] = lastQuantity;
    }

    setState(() => _productsLoading = true);

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
        setState(() => _productsLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
          actions: [
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final opening = _opening;

    if (opening == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
        ),
        body: Center(
          child: Text(
            'Este puesto no está abierto en este momento.',
            style: TextStyle(color: subtitleColor),
          ),
        ),
      );
    }

    final addressLabel =
    (opening['addressLabel'] ?? _stall?['currentAddressLabel'] ?? '')
        .toString()
        .trim();

    final status = (opening['status'] ?? 'OPEN').toString();
    final openedAt = _formatDate(opening['openedAt']?.toString());

    final inventoryItems =
        (opening['inventoryItems'] as List?)?.cast<dynamic>() ?? const [];

    final suggestions =
        (opening['inventorySuggestions'] as List?)?.cast<dynamic>() ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Mi puesto' : widget.stallName),
        actions: [
          IconButton(
            onPressed: shell == null ? null : shell.switchToBuyer,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Cambiar a comprador',
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _closeStall,
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Cerrar puesto',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _stall?['name']?.toString() ?? widget.stallName,
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Estado: $status • abierto desde $openedAt',
              style: TextStyle(color: subtitleColor),
            ),
            if (addressLabel.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AddressCard(
                label: addressLabel,
                onCopy: () async {
                  await Clipboard.setData(
                    ClipboardData(text: addressLabel),
                  );

                  if (!context.mounted) return;

                  AppSnackbar.success(context, 'Dirección copiada.');
                },
              ),
            ],
            const SizedBox(height: 16),
            _LocationCard(opening: opening),
            const SizedBox(height: 16),
            Text(
              'Imágenes',
              style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _ImageCard(
              label: 'Foto del puesto',
              imageUrl: _stallPhotoUrl,
            ),
            const SizedBox(height: 10),
            _ImageCard(
              label: 'Foto de productos',
              imageUrl: _productsPhotoUrl,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Productos detectados',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_productsLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  onPressed: _productsLoading
                      ? null
                      : () => _loadProducts(showLoader: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProductsCard(
              products: _products,
              subtitleColor: subtitleColor,
              onEdit: _editProduct,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Inventario extraído',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryList(
                    items: inventoryItems,
                    emptyText: 'Sin items detectados.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Sugerencias por foto',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionsList(
                    items: suggestions,
                    emptyText: 'Sin sugerencias.',
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

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
    required this.products,
    required this.subtitleColor,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> products;
  final Color subtitleColor;
  final void Function(Map<String, dynamic>) onEdit;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeColors.inputFill(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Todavía no hay productos. Abre el puesto con inventario para generarlos.',
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ...products.map((product) {
            final displayName =
            (product['display'] ?? product['canonical'] ?? 'Producto')
                .toString();

            final lastQuantity = (product['lastQty'] ?? 0).toString();
            final isActive = product['active'] == true;

            return Column(
              children: [
                ListTile(
                  title: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(color: subtitleColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('x$lastQuantity'),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => onEdit(product),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar',
                      ),
                    ],
                  ),
                ),
                if (product != products.last) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({
    required this.items,
    required this.emptyText,
  });

  final List<dynamic> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    if (items.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: subtitleColor),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.map((item) {
          final value = (item as Map).cast<String, dynamic>();
          final displayName =
          (value['display'] ?? value['canonical'] ?? 'Producto').toString();
          final quantity = (value['qty'] ?? 1).toString();

          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: Text(displayName),
            trailing: Text('x$quantity'),
          );
        }).toList(),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.items,
    required this.emptyText,
  });

  final List<dynamic> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppThemeColors.subtitleColor(context);

    if (items.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: subtitleColor),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          if (item is Map) {
            final value = item.cast<String, dynamic>();
            final label =
            (value['label'] ?? value['name'] ?? value['display'] ?? '')
                .toString();

            if (label.isEmpty) {
              return const SizedBox.shrink();
            }

            return Chip(label: Text(label));
          }

          return Chip(label: Text(item.toString()));
        }).toList(),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.onCopy,
  });

  final String label;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dirección actual',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(color: subtitleColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copiar',
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.opening});

  final Map<String, dynamic> opening;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    final latitude = (opening['lat'] as num?)?.toDouble();
    final longitude = (opening['lng'] as num?)?.toDouble();
    final accuracy = (opening['accuracy'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return Text(
        'Sin ubicación registrada.',
        style: TextStyle(color: subtitleColor),
      );
    }

    final point = LatLng(latitude, longitude);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ubicación',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'lat ${latitude.toStringAsFixed(6)} • '
                'lng ${longitude.toStringAsFixed(6)} • '
                '±${(accuracy ?? 0).toStringAsFixed(0)} m',
            style: TextStyle(color: subtitleColor),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'encuentrame.bo',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (imageUrl == null)
            Text(
              'No disponible.',
              style: TextStyle(color: subtitleColor),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}