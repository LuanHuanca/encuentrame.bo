import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class MarketStallDetailPage extends StatefulWidget {
  const MarketStallDetailPage({
    super.key,
    required this.stallId,
    this.userLat,
    this.userLng,
  });

  final String stallId;
  final double? userLat;
  final double? userLng;

  @override
  State<MarketStallDetailPage> createState() => _MarketStallDetailPageState();
}

class _MarketStallDetailPageState extends State<MarketStallDetailPage> {
  final RestClient _api = RestClient();

  bool _loading = true;
  String? _errorMessage;

  Map<String, dynamic>? _stall;
  Map<String, dynamic>? _opening;
  List<Map<String, dynamic>> _products = [];

  String? _stallPhotoUrl;
  String? _productsPhotoUrl;

  @override
  void initState() {
    super.initState();
    _load();
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

  String _formatDistance(num? meters) {
    final value = meters?.toDouble();
    if (value == null) return '';

    if (value < 1000) {
      return '${value.toStringAsFixed(0)} m';
    }

    return '${(value / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get(
        '/market/stalls/${widget.stallId}',
        queryParameters: {
          if (widget.userLat != null) 'lat': widget.userLat.toString(),
          if (widget.userLng != null) 'lng': widget.userLng.toString(),
        },
      );

      _stall = (response['stall'] as Map?)?.cast<String, dynamic>();
      _opening = (response['opening'] as Map?)?.cast<String, dynamic>();

      final rawProducts =
          (response['products'] as List?)?.cast<dynamic>() ?? const [];

      _products = rawProducts
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

      final stallPhotoKey = _opening?['stallPhotoKey'] as String?;
      final productsPhotoKey = _opening?['productsPhotoKey'] as String?;

      _stallPhotoUrl =
      stallPhotoKey == null ? null : await _getStorageUrl(stallPhotoKey);

      _productsPhotoUrl = productsPhotoKey == null
          ? null
          : await _getStorageUrl(productsPhotoKey);
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      _errorMessage = UserFriendlyMessages.fromApiError(error);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      _errorMessage = UserFriendlyMessages.fromGenericError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _stall == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puesto')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage ?? 'No se pudo cargar el puesto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subtitleColor),
            ),
          ),
        ),
      );
    }

    final stall = _stall!;
    final name = (stall['name'] ?? 'Puesto').toString();
    final category = (stall['category'] ?? '').toString().trim();
    final description = (stall['description'] ?? '').toString().trim();
    final address = (stall['addressLabel'] ?? '').toString().trim();
    final distance = _formatDistance(stall['distanceMeters'] as num?);

    final lat = (stall['lat'] as num?)?.toDouble();
    final lng = (stall['lng'] as num?)?.toDouble();
    final point = (lat != null && lng != null) ? LatLng(lat, lng) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeColors.inputFill(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (category.isNotEmpty) Chip(label: Text(category)),
                      Chip(
                        label: Text(
                          stall['isOpen'] == true ? 'Abierto' : 'Cerrado',
                        ),
                      ),
                      if (distance.isNotEmpty) Chip(label: Text(distance)),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(color: subtitleColor),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(color: subtitleColor),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: address));
                            if (!context.mounted) return;
                            AppSnackbar.success(context, 'Dirección copiada.');
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (point != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeColors.inputFill(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
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
                              width: 44,
                              height: 44,
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
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Fotos del puesto',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            if (_stallPhotoUrl == null && _productsPhotoUrl == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemeColors.inputFill(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'No hay fotos disponibles.',
                  style: TextStyle(color: subtitleColor),
                ),
              ),
            if (_stallPhotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _stallPhotoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (_productsPhotoUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _productsPhotoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Todos los productos',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            if (_products.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemeColors.inputFill(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Este puesto todavía no tiene productos visibles.',
                  style: TextStyle(color: subtitleColor),
                ),
              )
            else
              ..._products.map((product) {
                final productName =
                (product['display'] ?? product['canonical'] ?? 'Producto')
                    .toString();
                final productCategory =
                (product['category'] ?? '').toString().trim();
                final productDescription =
                (product['description'] ?? '').toString().trim();
                final qty = (product['lastQty'] ?? '').toString();
                final price = product['price'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppThemeColors.inputFill(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (price != null)
                            Text(
                              'Bs ${price.toString()}',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (productCategory.isNotEmpty)
                            Chip(label: Text(productCategory)),
                          if (qty.isNotEmpty) Chip(label: Text('x$qty')),
                        ],
                      ),
                      if (productDescription.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          productDescription,
                          style: TextStyle(color: subtitleColor),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}