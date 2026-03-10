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
  String _activeModeLabel = 'Productos cercanos';

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

    if (value < 1000) {
      return '${value.toStringAsFixed(0)} m';
    }

    return '${(value / 1000).toStringAsFixed(1)} km';
  }

  List<Map<String, dynamic>> _sortResults(
      List<Map<String, dynamic>> items,
      ) {
    final sorted = List<Map<String, dynamic>>.from(items);

    sorted.sort((a, b) {
      final aDistance =
          (a['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
      final bDistance =
          (b['distanceMeters'] as num?)?.toDouble() ?? double.infinity;

      if (aDistance != bDistance) {
        return aDistance.compareTo(bDistance);
      }

      final aProduct =
      ((a['product'] as Map?) ?? const {}).cast<String, dynamic>();
      final bProduct =
      ((b['product'] as Map?) ?? const {}).cast<String, dynamic>();

      final aName =
      (aProduct['display'] ?? aProduct['canonical'] ?? '').toString();
      final bName =
      (bProduct['display'] ?? bProduct['canonical'] ?? '').toString();

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
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Todos';
        }
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
        setState(() {
          _errorMessage =
          'El permiso de ubicación está bloqueado. Habilítalo desde ajustes.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() => _position = position);

      await _loadInitialNearbyProducts();
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() => _errorMessage = 'No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _loadInitialNearbyProducts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _activeModeLabel = 'Productos cercanos';
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

      final stalls = rawStalls
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

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
      await _loadInitialNearbyProducts();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = [];
      _activeModeLabel = 'Resultados para "$query"';
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

      final results = rawResults
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;

      setState(() {
        _results = _sortResults(results);
        _loading = false;
        _hasLoadedOnce = true;
      });

      if (_results.isEmpty) {
        AppSnackbar.info(
          context,
          'No encontramos "$query" cerca. Intenta con otra palabra.',
        );
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

  Future<void> _openStallDetail({
    required String stallId,
  }) async {
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
                  Text(
                    stallName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (addressLabel.isNotEmpty)
                    Text(
                      addressLabel,
                      style: TextStyle(
                        color: AppThemeColors.subtitleColor(context),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_pin,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: '$latitude,$longitude'),
                            );

                            if (!context.mounted) return;

                            Navigator.pop(sheetContext);
                            AppSnackbar.success(
                              context,
                              'Coordenadas copiadas.',
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiar coordenadas'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationPill() {
    final hasLocation = _hasLocation;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasLocation
            ? AppColors.statusOpen.withValues(alpha: 0.12)
            : AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasLocation
              ? AppColors.statusOpen.withValues(alpha: 0.35)
              : Theme.of(context).dividerColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasLocation
                ? Icons.check_circle_rounded
                : Icons.location_searching_rounded,
            size: 16,
            color: hasLocation ? AppColors.statusOpen : null,
          ),
          const SizedBox(width: 8),
          Text(
            hasLocation ? 'Ubicación activa' : 'Ubicación pendiente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hasLocation ? AppColors.statusOpen : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(Color titleColor, Color subtitleColor) {
    if (_loading && _results.isEmpty && _openStalls.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _hasQuery ? _results.length : _openStalls.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.inputFill(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeModeLabel,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total resultado${total == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.view_list_rounded),
                label: Text('Lista'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.map_outlined),
                label: Text('Mapa'),
              ),
            ],
            selected: {_mapMode},
            onSelectionChanged: (values) {
              setState(() => _mapMode = values.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color subtitleColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                ),
                items: _categories
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedCategory = value);

                  if (_hasQuery) {
                    await _searchProducts();
                  } else {
                    await _loadInitialNearbyProducts();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: _limit,
                decoration: const InputDecoration(
                  labelText: 'Límite',
                ),
                items: const [10, 25, 50, 100]
                    .map(
                      (item) => DropdownMenuItem<int>(
                    value: item,
                    child: Text(item.toString()),
                  ),
                )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _limit = value);

                  if (_hasQuery) {
                    await _searchProducts();
                  } else {
                    await _loadInitialNearbyProducts();
                  }
                },
              ),
            ),
          ],
        ),
        if (_mapMode) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            value: _showUserMarker,
            onChanged: (value) => setState(() => _showUserMarker = value),
            title: const Text('Mostrar mi ubicación'),
            subtitle: Text(
              'Activa o desactiva tu pin personal en el mapa.',
              style: TextStyle(color: subtitleColor),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(Color subtitleColor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    if (!_hasLoadedOnce) {
      return Center(
        child: Text(
          'Cargando resultados...',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    return Center(
      child: Text(
        _hasQuery
            ? 'No encontramos productos para esta búsqueda.'
            : 'No hay puestos abiertos cerca por ahora.',
        textAlign: TextAlign.center,
        style: TextStyle(color: subtitleColor),
      ),
    );
  }

  Widget _buildMapView() {
    if (_openStalls.isEmpty && !_hasLocation) {
      return _buildEmptyState(AppThemeColors.subtitleColor(context));
    }

    final userPoint = _hasLocation
        ? LatLng(_position!.latitude, _position!.longitude)
        : null;

    LatLng initialCenter;
    if (_openStalls.isNotEmpty) {
      final firstLat = (_openStalls.first['lat'] as num?)?.toDouble();
      final firstLng = (_openStalls.first['lng'] as num?)?.toDouble();

      if (firstLat != null && firstLng != null) {
        initialCenter = LatLng(firstLat, firstLng);
      } else if (userPoint != null) {
        initialCenter = userPoint;
      } else {
        initialCenter = const LatLng(-16.5, -68.15);
      }
    } else if (userPoint != null) {
      initialCenter = userPoint;
    } else {
      initialCenter = const LatLng(-16.5, -68.15);
    }

    final markers = <Marker>[];

    for (final stall in _openStalls) {
      final lat = (stall['lat'] as num?)?.toDouble();
      final lng = (stall['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () {
              final stallId = (stall['stallId'] ?? '').toString();
              if (stallId.isEmpty) return;

              _openStallDetail(stallId: stallId);
            },
            child: Container(
              alignment: Alignment.center,
              child: const Icon(
                Icons.location_on,
                size: 40,
              ),
            ),
          ),
        ),
      );
    }

    if (_showUserMarker && userPoint != null) {
      markers.add(
        Marker(
          point: userPoint,
          width: 44,
          height: 44,
          child: const Icon(
            Icons.my_location_rounded,
            size: 28,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 14,
        ),
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

  Widget _buildListView(Color titleColor, Color subtitleColor) {
    if (_hasQuery) {
      if (_results.isEmpty) {
        return _buildEmptyState(subtitleColor);
      }

      return ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final result = _results[index];

          final product = (result['product'] is Map)
              ? (result['product'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

          final productName =
          (product['display'] ?? product['canonical'] ?? 'Producto')
              .toString();

          final stallName = (result['stallName'] ?? 'Puesto').toString();
          final stallCategory =
          (result['stallCategory'] ?? '').toString().trim();
          final addressLabel = (result['addressLabel'] ?? '').toString().trim();
          final distanceLabel =
          _formatDistance(result['distanceMeters'] as num?);
          final stallId = (result['stallId'] ?? '').toString();

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: stallId.isEmpty
                  ? null
                  : () => _openStallDetail(stallId: stallId),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stallName,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceLabel.isNotEmpty)
                          Text(
                            distanceLabel,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (stallCategory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Chip(label: Text(stallCategory)),
                    ],
                    if (addressLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
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
                            onPressed: stallId.isEmpty
                                ? null
                                : () => _openStallDetail(stallId: stallId),
                            icon: const Icon(Icons.store_mall_directory_outlined),
                            label: const Text('Ver puesto'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showLocationSheet(result),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Ubicación'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (_openStalls.isEmpty) {
      return _buildEmptyState(subtitleColor);
    }

    return ListView.separated(
      itemCount: _openStalls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final stall = _openStalls[index];

        final stallId = (stall['stallId'] ?? '').toString();
        final stallName = (stall['name'] ?? 'Puesto').toString();
        final stallCategory = (stall['category'] ?? '').toString().trim();
        final stallDescription = (stall['description'] ?? '').toString().trim();
        final addressLabel = (stall['addressLabel'] ?? '').toString().trim();
        final distanceLabel =
        _formatDistance(stall['distanceMeters'] as num?);

        final preview =
            (stall['productsPreview'] as List?)?.cast<dynamic>() ?? const [];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: stallId.isEmpty
                ? null
                : () => _openStallDetail(stallId: stallId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stallName,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (stallCategory.isNotEmpty) Chip(label: Text(stallCategory)),
                      if (distanceLabel.isNotEmpty) Chip(label: Text(distanceLabel)),
                    ],
                  ),
                  if (stallDescription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      stallDescription,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Productos visibles',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: preview.map((item) {
                        final product =
                        (item as Map).cast<String, dynamic>();
                        final productName =
                        (product['display'] ?? product['canonical'] ?? '')
                            .toString()
                            .trim();

                        if (productName.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Chip(label: Text(productName));
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: stallId.isEmpty
                              ? null
                              : () => _openStallDetail(stallId: stallId),
                          icon: const Icon(Icons.store_mall_directory_outlined),
                          label: const Text('Ver puesto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showLocationSheet({
                            'lat': stall['lat'],
                            'lng': stall['lng'],
                            'addressLabel': stall['addressLabel'],
                            'stallName': stallName,
                          }),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Ubicación'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);

    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MarketHowItWorksPage(),
                ),
              );
            },
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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Encuentra vendedores y productos cerca de ti',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes explorar en lista o mapa, filtrar por categoría y decidir cuántos puestos cargar.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildLocationPill(),
                    const Spacer(),
                    IconButton(
                      onPressed:
                      (_gettingLocation || _loading) ? null : _ensureLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      tooltip: 'Actualizar ubicación',
                    ),
                    IconButton(
                      onPressed:
                      (_gettingLocation || _loading) ? null : _loadCategories,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchProducts(),
                  decoration: InputDecoration(
                    labelText: 'Buscar producto',
                    hintText: 'Ejemplo: pipocas, api, poleras',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadInitialNearbyProducts();
                      },
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Limpiar',
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildFilters(subtitleColor),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                    (_loading || _gettingLocation) ? null : _searchProducts,
                    icon: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Icon(
                      _hasQuery
                          ? Icons.search_rounded
                          : Icons.near_me_rounded,
                    ),
                    label: Text(
                      _loading
                          ? 'Cargando...'
                          : (_hasQuery ? 'Buscar' : 'Ver cercanos'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildResultsHeader(titleColor, subtitleColor),
                Expanded(
                  child: _mapMode
                      ? _buildMapView()
                      : _buildListView(titleColor, subtitleColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}