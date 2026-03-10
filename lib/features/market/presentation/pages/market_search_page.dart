import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/shell/main_shell.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import 'market_how_it_works_page.dart';
import 'market_stall_detail_page.dart';

class MarketSearchPage extends StatefulWidget {
  const MarketSearchPage({super.key});

  @override
  State<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends State<MarketSearchPage> {
  static const String _radiusKm = '10';
  static const String _defaultProductsPerStall = '20';

  final RestClient _api = RestClient();
  final TextEditingController _searchController = TextEditingController();

  Position? _position;

  bool _gettingLocation = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  bool _mapMode = false;
  bool _showUserMarker = true;

  String? _errorMessage;
  String _activeModeLabel = 'Puestos cercanos';

  int _limit = 50;
  String _selectedCategory = 'Todos';

  List<String> _categories = ['Todos'];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _openStalls = [];

  bool get _hasLocation => _position != null;
  bool get _hasQuery => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ensureLocation();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDistance(num? meters) {
    final value = meters?.toDouble();
    if (value == null) return '';
    if (value < 1000) return '${value.toStringAsFixed(0)} m';
    return '${(value / 1000).toStringAsFixed(1)} km';
  }

  List<Map<String, dynamic>> _sortResults(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aD = (a['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
      final bD = (b['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
      if (aD != bD) return aD.compareTo(bD);
      final aP = ((a['product'] as Map?) ?? const {}).cast<String, dynamic>();
      final bP = ((b['product'] as Map?) ?? const {}).cast<String, dynamic>();
      final aName = (aP['display'] ?? aP['canonical'] ?? '').toString();
      final bName = (bP['display'] ?? bP['canonical'] ?? '').toString();
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return sorted;
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _api.get('/market/categories');
      final values = ((response['categories'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _categories = ['Todos', ...values];
        if (!_categories.contains(_selectedCategory)) _selectedCategory = 'Todos';
      });
    } catch (_) {}
  }

  Future<void> _ensureLocation() async {
    setState(() {
      _gettingLocation = true;
      _errorMessage = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Activa el GPS para usar la app.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = 'Permiso de ubicación denegado.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage =
            'El permiso de ubicación está bloqueado. Habilítalo desde ajustes.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _position = position);
      await _loadInitialNearbyStalls();
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _loadInitialNearbyStalls() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _activeModeLabel = 'Puestos cercanos';
    });
    try {
      final response = await _api.get(
        '/market/open-stalls',
        queryParameters: {
          if (_hasLocation) 'lat': _position!.latitude.toString(),
          if (_hasLocation) 'lng': _position!.longitude.toString(),
          'radiusKm': _radiusKm,
          'limit': _limit.toString(),
          'includeProducts': '1',
          'productsLimit': _defaultProductsPerStall,
          if (_selectedCategory != 'Todos') 'category': _selectedCategory,
        },
      );
      final rawStalls =
          (response['stalls'] as List?)?.cast<dynamic>() ?? const [];
      final stalls =
          rawStalls.map((item) => (item as Map).cast<String, dynamic>()).toList();

      final items = <Map<String, dynamic>>[];
      for (final stall in stalls) {
        final stallId = (stall['stallId'] ?? '').toString();
        final stallName = (stall['name'] ?? 'Puesto').toString();
        final preview =
            (stall['productsPreview'] as List?)?.cast<dynamic>() ?? const [];
        for (final rawProduct in preview) {
          final product = (rawProduct as Map).cast<String, dynamic>();
          items.add({
            'stallId': stallId,
            'stallName': stallName,
            'stallCategory': stall['category'],
            'stallDescription': stall['description'],
            'distanceMeters': stall['distanceMeters'],
            'addressLabel': stall['addressLabel'],
            'lat': stall['lat'],
            'lng': stall['lng'],
            'product': product,
          });
        }
      }
      if (!mounted) return;
      setState(() {
        _openStalls = stalls;
        _results = _sortResults(items);
        _loading = false;
        _hasLoadedOnce = true;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      final message = UserFriendlyMessages.fromApiError(error);
      setState(() {
        _errorMessage = message;
        _loading = false;
        _hasLoadedOnce = true;
      });
      AppSnackbar.error(context, message);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      final message = UserFriendlyMessages.fromGenericError(error);
      setState(() {
        _errorMessage = message;
        _loading = false;
        _hasLoadedOnce = true;
      });
      AppSnackbar.error(context, message);
    }
  }

  Future<void> _searchProducts() async {
    FocusScope.of(context).unfocus();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _loadInitialNearbyStalls();
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = [];
      _activeModeLabel = '"$query"';
    });
    try {
      final response = await _api.get(
        '/market/products/search',
        queryParameters: {
          if (_hasLocation) 'lat': _position!.latitude.toString(),
          if (_hasLocation) 'lng': _position!.longitude.toString(),
          'q': query,
          'radiusKm': _radiusKm,
          'limit': _limit.toString(),
          if (_selectedCategory != 'Todos') 'category': _selectedCategory,
        },
      );
      final rawResults =
          (response['results'] as List?)?.cast<dynamic>() ?? const [];
      final results =
          rawResults.map((item) => (item as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() {
        _results = _sortResults(results);
        _loading = false;
        _hasLoadedOnce = true;
      });
      if (_results.isEmpty) {
        AppSnackbar.info(
            context, 'No encontramos "$query" cerca. Intenta con otra palabra.');
      }
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      final message = UserFriendlyMessages.fromApiError(error);
      setState(() {
        _errorMessage = message;
        _loading = false;
        _hasLoadedOnce = true;
      });
      AppSnackbar.error(context, message);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);
      if (!mounted) return;
      final message = UserFriendlyMessages.fromGenericError(error);
      setState(() {
        _errorMessage = message;
        _loading = false;
        _hasLoadedOnce = true;
      });
      AppSnackbar.error(context, message);
    }
  }

  Future<void> _openStallDetail({required String stallId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketStallDetailPage(
          stallId: stallId,
          userLat: _position?.latitude,
          userLng: _position?.longitude,
        ),
      ),
    );
  }

  void _showLocationSheet(Map<String, dynamic> result) {
    final latitude = (result['lat'] as num?)?.toDouble();
    final longitude = (result['lng'] as num?)?.toDouble();
    final addressLabel = (result['addressLabel'] ?? '').toString().trim();
    final stallName = (result['stallName'] ?? 'Puesto').toString();

    if (latitude == null || longitude == null) {
      AppSnackbar.info(context, 'Este resultado no tiene coordenadas.');
      return;
    }
    final point = LatLng(latitude, longitude);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stallName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (addressLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(addressLabel,
                        style: TextStyle(
                            color: AppThemeColors.subtitleColor(context),
                            fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                              width: 48,
                              height: 48,
                              child: const Icon(Icons.location_pin,
                                  size: 42, color: AppColors.orangeAccent),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: '$latitude,$longitude'));
                        if (!context.mounted) return;
                        Navigator.pop(sheetContext);
                        AppSnackbar.success(context, 'Coordenadas copiadas.');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar coordenadas'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtros de búsqueda',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories
                          .map((item) => DropdownMenuItem<String>(
                              value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {});
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      value: _limit,
                      decoration: const InputDecoration(
                        labelText: 'Límite de resultados',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      items: const [10, 25, 50, 100]
                          .map((item) => DropdownMenuItem<int>(
                              value: item, child: Text(item.toString())))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {});
                        setState(() => _limit = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _showUserMarker,
                      onChanged: (value) {
                        setSheetState(() {});
                        setState(() => _showUserMarker = value);
                      },
                      title: const Text('Mostrar mi ubicación en mapa'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          if (_hasQuery) {
                            await _searchProducts();
                          } else {
                            await _loadInitialNearbyStalls();
                          }
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Map view ──────────────────────────────────────────────────────────────

  Widget _buildMapView() {
    final subtitleColor = AppThemeColors.subtitleColor(context);
    if (_openStalls.isEmpty && !_hasLocation) return _buildEmptyState(subtitleColor);

    final userPoint =
        _hasLocation ? LatLng(_position!.latitude, _position!.longitude) : null;

    LatLng initialCenter;
    if (_openStalls.isNotEmpty) {
      final firstLat = (_openStalls.first['lat'] as num?)?.toDouble();
      final firstLng = (_openStalls.first['lng'] as num?)?.toDouble();
      if (firstLat != null && firstLng != null) {
        initialCenter = LatLng(firstLat, firstLng);
      } else {
        initialCenter = userPoint ?? const LatLng(-16.5, -68.15);
      }
    } else {
      initialCenter = userPoint ?? const LatLng(-16.5, -68.15);
    }

    final markers = <Marker>[];
    for (final stall in _openStalls) {
      final lat = (stall['lat'] as num?)?.toDouble();
      final lng = (stall['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 56,
        height: 56,
        child: GestureDetector(
          onTap: () {
            final stallId = (stall['stallId'] ?? '').toString();
            if (stallId.isEmpty) return;
            _openStallDetail(stallId: stallId);
          },
          child: const Icon(Icons.location_on, size: 40, color: AppColors.orangeAccent),
        ),
      ));
    }
    if (_showUserMarker && userPoint != null) {
      markers.add(Marker(
        point: userPoint,
        width: 44,
        height: 44,
        child: const Icon(Icons.my_location_rounded, size: 28, color: AppColors.primary),
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        options: MapOptions(initialCenter: initialCenter, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'encuentrame.bo',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  // ─── Empty / loading state ─────────────────────────────────────────────────

  Widget _buildEmptyState(Color subtitleColor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: subtitleColor),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtitleColor)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _ensureLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_hasLoadedOnce) {
      return Center(
        child: Text('Cargando resultados...',
            style: TextStyle(color: subtitleColor)),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasQuery ? Icons.search_off_rounded : Icons.storefront_outlined,
            size: 48,
            color: subtitleColor,
          ),
          const SizedBox(height: 12),
          Text(
            _hasQuery
                ? 'No encontramos productos para esta búsqueda.'
                : 'No hay puestos abiertos cerca por ahora.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor),
          ),
        ],
      ),
    );
  }

  // ─── Stall card (premium design) ──────────────────────────────────────────

  Widget _buildStallCard(
      Map<String, dynamic> stall, Color titleColor, Color subtitleColor) {
    final stallId = (stall['stallId'] ?? '').toString();
    final stallName = (stall['name'] ?? 'Puesto').toString();
    final stallCategory = (stall['category'] ?? '').toString().trim();
    final addressLabel = (stall['addressLabel'] ?? '').toString().trim();
    final distanceLabel = _formatDistance(stall['distanceMeters'] as num?);

    final preview =
        (stall['productsPreview'] as List?)?.cast<dynamic>() ?? const [];
    final previewText = preview
        .map((item) {
          final p = (item as Map).cast<String, dynamic>();
          return (p['display'] ?? p['canonical'] ?? '').toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .take(5)
        .join(' · ');

    // Avatar letter
    final initials = stallName.trim().isNotEmpty
        ? stallName.trim()[0].toUpperCase()
        : 'P';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: stallId.isEmpty ? null : () => _openStallDetail(stallId: stallId),
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeColors.inputFill(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.blueNeon],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text info
                Expanded(
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                distanceLabel,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (stallCategory.isNotEmpty || addressLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (stallCategory.isNotEmpty) stallCategory,
                            if (addressLabel.isNotEmpty) addressLabel,
                          ].join(' · '),
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (previewText.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 12, color: subtitleColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                previewText,
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Map icon button
                GestureDetector(
                  onTap: () => _showLocationSheet({
                    'lat': stall['lat'],
                    'lng': stall['lng'],
                    'addressLabel': stall['addressLabel'],
                    'stallName': stallName,
                  }),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppThemeColors.inputFill(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.map_outlined,
                        size: 18, color: subtitleColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Product card (search results) ────────────────────────────────────────

  Widget _buildProductCard(Map<String, dynamic> result, Color titleColor,
      Color subtitleColor) {
    final product = (result['product'] is Map)
        ? (result['product'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final productName =
        (product['display'] ?? product['canonical'] ?? 'Producto').toString();
    final stallName = (result['stallName'] ?? 'Puesto').toString();
    final stallCategory = (result['stallCategory'] ?? '').toString().trim();
    final addressLabel = (result['addressLabel'] ?? '').toString().trim();
    final distanceLabel = _formatDistance(result['distanceMeters'] as num?);
    final stallId = (result['stallId'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: stallId.isEmpty ? null : () => _openStallDetail(stallId: stallId),
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeColors.inputFill(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Product icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.orangeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shopping_bag_outlined,
                      size: 22, color: AppColors.orangeAccent),
                ),
                const SizedBox(width: 12),

                // Info
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                distanceLabel,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.storefront_outlined,
                              size: 12, color: subtitleColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                stallName,
                                if (stallCategory.isNotEmpty) stallCategory,
                                if (addressLabel.isNotEmpty) addressLabel,
                              ].join(' · '),
                              style:
                                  TextStyle(color: subtitleColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                GestureDetector(
                  onTap: () => _showLocationSheet(result),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppThemeColors.inputFill(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.map_outlined,
                        size: 18, color: subtitleColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── List view ─────────────────────────────────────────────────────────────

  Widget _buildListView(Color titleColor, Color subtitleColor) {
    if (_hasQuery) {
      if (_results.isEmpty) return _buildEmptyState(subtitleColor);
      return ListView.separated(
        itemCount: _results.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) =>
            _buildProductCard(_results[i], titleColor, subtitleColor),
      );
    }
    if (_openStalls.isEmpty) return _buildEmptyState(subtitleColor);
    return ListView.separated(
      itemCount: _openStalls.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _buildStallCard(_openStalls[i], titleColor, subtitleColor),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _hasQuery ? _results.length : _openStalls.length;

    return Scaffold(
      // ── Gradient AppBar ──────────────────────────────────────────────────
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
        title: const Text(
          'Market',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // Location indicator
          if (_hasLocation)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_gettingLocation)
            const Padding(
              padding: EdgeInsets.only(right: 8, left: 4),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MarketHowItWorksPage())),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Cómo funciona',
          ),
          IconButton(
            onPressed: shell == null ? null : shell.switchToVendor,
            icon: const Icon(Icons.storefront_rounded),
            tooltip: 'Cambiar a vendedor',
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
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchProducts(),
                        style: TextStyle(fontSize: 14, color: titleColor),
                        decoration: InputDecoration(
                          hintText: 'Buscar productos o puestos...',
                          hintStyle:
                              TextStyle(color: subtitleColor, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                    _loadInitialNearbyStalls();
                                  },
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18),
                                ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppThemeColors.inputFill(context),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search button
                  _SquareButton(
                    onTap: (_loading || _gettingLocation)
                        ? null
                        : _searchProducts,
                    tooltip: _hasQuery ? 'Buscar' : 'Ver cercanos',
                    color: AppColors.orangeAccent,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _hasQuery
                                ? Icons.search_rounded
                                : Icons.near_me_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 6),
                  // Filter button
                  _SquareButton(
                    onTap: _showFiltersSheet,
                    tooltip: 'Filtros',
                    color: _selectedCategory != 'Todos'
                        ? AppColors.primary
                        : null,
                    outlined: _selectedCategory == 'Todos',
                    child: Icon(
                      Icons.tune_rounded,
                      size: 22,
                      color: _selectedCategory != 'Todos'
                          ? Colors.white
                          : subtitleColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Results meta bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeModeLabel,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_hasLoadedOnce && !_loading)
                          Text(
                            '$total resultado${total == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: subtitleColor, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  // Refresh location
                  IconButton(
                    onPressed: (_gettingLocation || _loading)
                        ? null
                        : _ensureLocation,
                    icon: Icon(Icons.my_location_rounded,
                        size: 20, color: subtitleColor),
                    tooltip: 'Actualizar ubicación',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  // Toggle lista / mapa — compact pill
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppThemeColors.inputFill(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleTab(
                          icon: Icons.view_list_rounded,
                          active: !_mapMode,
                          onTap: () => setState(() => _mapMode = false),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.3),
                        ),
                        _ToggleTab(
                          icon: Icons.map_outlined,
                          active: _mapMode,
                          onTap: () => setState(() => _mapMode = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Results area ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: _mapMode
                    ? _buildMapView()
                    : _buildListView(titleColor, subtitleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.child,
    required this.onTap,
    this.tooltip,
    this.color,
    this.outlined = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.transparent;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: onTap == null ? bg.withValues(alpha: 0.4) : bg,
            borderRadius: BorderRadius.circular(14),
            border: outlined
                ? Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.4),
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 34,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: active ? AppColors.primary : AppThemeColors.subtitleColor(context),
        ),
      ),
    );
  }
}