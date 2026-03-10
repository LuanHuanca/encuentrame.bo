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
    if (value < 1000) return '${value.toStringAsFixed(0)} m';
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
                (b['display'] ?? b['canonical'] ?? '').toString().toLowerCase()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory_outlined,
                    size: 52, color: subtitleColor),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No se pudo cargar el puesto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
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
    final isOpen = stall['isOpen'] == true;

    final lat = (stall['lat'] as num?)?.toDouble();
    final lng = (stall['lng'] as num?)?.toDouble();
    final point = (lat != null && lng != null) ? LatLng(lat, lng) : null;

    // Avatar initial
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.blueSurface, AppColors.primaryDark]
                  : [AppColors.primary, AppColors.blueNeon],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text(
          name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.backgroundGradient(context),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              // ── Hero info card ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppThemeColors.inputFill(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Header gradient strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppColors.primaryDark.withValues(alpha: 0.8),
                                  AppColors.blueSurface.withValues(alpha: 0.8),
                                ]
                              : [
                                  AppColors.primary.withValues(alpha: 0.08),
                                  AppColors.blueNeon.withValues(alpha: 0.06),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.blueNeon],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (category.isNotEmpty)
                                      _InfoPill(
                                        label: category,
                                        color: AppColors.blueNeon,
                                      ),
                                    _InfoPill(
                                      label: isOpen ? 'Abierto' : 'Cerrado',
                                      color: isOpen
                                          ? AppColors.statusOpen
                                          : AppColors.statusClosed,
                                      icon: isOpen
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.cancel_outlined,
                                    ),
                                    if (distance.isNotEmpty)
                                      _InfoPill(
                                        label: distance,
                                        color: AppColors.orangeBright,
                                        icon: Icons.near_me_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (description.isNotEmpty) ...[
                            Text(
                              description,
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 14,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (address.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(
                                        color: subtitleColor, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: address));
                                    if (!context.mounted) return;
                                    AppSnackbar.success(
                                        context, 'Dirección copiada.');
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.copy_rounded,
                                        size: 16, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Map ────────────────────────────────────────────────────
              if (point != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                          initialCenter: point, initialZoom: 16),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'encuentrame.bo',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_pin,
                                size: 40, color: AppColors.orangeAccent),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Photos ─────────────────────────────────────────────────
              if (_stallPhotoUrl != null || _productsPhotoUrl != null) ...[
                const SizedBox(height: 20),
                _SectionLabel(label: 'Fotos del puesto', titleColor: titleColor),
                const SizedBox(height: 10),
                if (_stallPhotoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _stallPhotoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_productsPhotoUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _productsPhotoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],

              // ── Products ───────────────────────────────────────────────
              const SizedBox(height: 20),
              _SectionLabel(
                label: 'Productos del puesto',
                count: _products.length,
                titleColor: titleColor,
              ),
              const SizedBox(height: 10),
              if (_products.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeColors.inputFill(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 22, color: subtitleColor),
                      const SizedBox(width: 12),
                      Text(
                        'Este puesto no tiene productos visibles.',
                        style: TextStyle(color: subtitleColor, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_products.length, (index) {
                  final product = _products[index];
                  final productName =
                      (product['display'] ?? product['canonical'] ?? 'Producto')
                          .toString();
                  final productCategory =
                      (product['category'] ?? '').toString().trim();
                  final productDescription =
                      (product['description'] ?? '').toString().trim();
                  final qty = (product['lastQty'] ?? '').toString().trim();
                  final price = product['price'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppThemeColors.inputFill(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Number badge
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.orangeAccent
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.orangeAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (price != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.statusOpen
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Bs ${price.toString()}',
                                            style: const TextStyle(
                                              color: AppColors.statusOpen,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (productCategory.isNotEmpty ||
                                      qty.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        if (productCategory.isNotEmpty)
                                          _MiniTag(label: productCategory),
                                        if (qty.isNotEmpty)
                                          _MiniTag(
                                              label: 'x$qty',
                                              color: AppColors.blueNeon),
                                      ],
                                    ),
                                  ],
                                  if (productDescription.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      productDescription,
                                      style: TextStyle(
                                          color: subtitleColor, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.titleColor,
    this.count,
  });
  final String label;
  final Color titleColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppThemeColors.subtitleColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}