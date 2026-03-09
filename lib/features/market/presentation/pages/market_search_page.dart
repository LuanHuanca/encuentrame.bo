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

class MarketSearchPage extends StatefulWidget {
  const MarketSearchPage({super.key});

  @override
  State<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends State<MarketSearchPage> {
  static const String _radiusKm = '10';
  static const String _defaultNearbyLimit = '100';
  static const String _defaultProductsPerStall = '20';

  final RestClient _api = RestClient();
  final TextEditingController _searchController = TextEditingController();

  Position? _position;
  bool _gettingLocation = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;

  String? _errorMessage;
  String _activeModeLabel = 'Productos cercanos';
  List<Map<String, dynamic>> _results = [];

  bool get _hasLocation => _position != null;
  bool get _hasQuery => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ensureLocation();
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

      final aProduct = ((a['product'] as Map?) ?? const {})
          .cast<String, dynamic>();
      final bProduct = ((b['product'] as Map?) ?? const {})
          .cast<String, dynamic>();

      final aName =
      (aProduct['display'] ?? aProduct['canonical'] ?? '').toString();
      final bName =
      (bProduct['display'] ?? bProduct['canonical'] ?? '').toString();

      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return sorted;
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
    if (!_hasLocation) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _activeModeLabel = 'Productos cercanos';
    });

    try {
      final response = await _api.get(
        '/market/open-stalls',
        queryParameters: {
          'lat': _position!.latitude.toString(),
          'lng': _position!.longitude.toString(),
          'radiusKm': _radiusKm,
          'limit': _defaultNearbyLimit,
          'includeProducts': '1',
          'productsLimit': _defaultProductsPerStall,
        },
      );

      final rawStalls =
          (response['stalls'] as List?)?.cast<dynamic>() ?? const [];

      final items = <Map<String, dynamic>>[];

      for (final rawItem in rawStalls) {
        final stall = (rawItem as Map).cast<String, dynamic>();

        final stallId = (stall['stallId'] ?? '').toString();
        final stallName = (stall['name'] ?? 'Puesto').toString();

        final preview =
            (stall['productsPreview'] as List?)?.cast<dynamic>() ?? const [];

        for (final rawProduct in preview) {
          final product = (rawProduct as Map).cast<String, dynamic>();

          items.add({
            'stallId': stallId,
            'stallName': stallName,
            'distanceMeters': stall['distanceMeters'],
            'addressLabel': stall['addressLabel'],
            'lat': stall['lat'],
            'lng': stall['lng'],
            'product': product,
          });
        }
      }

      final sorted = _sortResults(items);

      if (!mounted) return;

      setState(() {
        _results = sorted;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } on ApiClientException catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = UserFriendlyMessages.fromApiError(error);
        _loading = false;
        _hasLoadedOnce = true;
      });

      AppSnackbar.error(context, _errorMessage!);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = UserFriendlyMessages.fromGenericError(error);
        _loading = false;
        _hasLoadedOnce = true;
      });

      AppSnackbar.error(context, _errorMessage!);
    }
  }

  Future<void> _searchProducts() async {
    FocusScope.of(context).unfocus();

    if (!_hasLocation) {
      AppSnackbar.error(context, 'Primero necesitamos tu ubicación.');
      return;
    }

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
          'lat': _position!.latitude.toString(),
          'lng': _position!.longitude.toString(),
          'q': query,
          'radiusKm': _radiusKm,
          'limit': _defaultNearbyLimit,
        },
      );

      final rawResults =
          (response['results'] as List?)?.cast<dynamic>() ?? const [];

      final results = rawResults
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      final sorted = _sortResults(results);

      if (!mounted) return;

      setState(() {
        _results = sorted;
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

      setState(() {
        _errorMessage = UserFriendlyMessages.fromApiError(error);
        _loading = false;
        _hasLoadedOnce = true;
      });

      AppSnackbar.error(context, _errorMessage!);
    } catch (error, stackTrace) {
      UserFriendlyMessages.logToConsole(error, stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = UserFriendlyMessages.fromGenericError(error);
        _loading = false;
        _hasLoadedOnce = true;
      });

      AppSnackbar.error(context, _errorMessage!);
    }
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
    if (_loading && _results.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  _results.isEmpty
                      ? 'Mostramos productos disponibles cerca de ti.'
                      : '${_results.length} resultado${_results.length == 1 ? '' : 's'} • ordenados del más cercano al más lejano',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color subtitleColor) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
          'Cargando productos cercanos...',
          style: TextStyle(color: subtitleColor),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: Text(
        'No hay productos cercanos disponibles por ahora.',
        style: TextStyle(color: subtitleColor),
        textAlign: TextAlign.center,
      ),
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
                  'Encuentra vendedores ambulantes cerca de ti',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te mostramos productos cercanos automáticamente. También puedes escribir algo específico si quieres filtrar.',
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
                    hintText: 'Opcional. Ejemplo: pipocas, api, poleras',
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
                  child: _results.isEmpty
                      ? _buildEmptyState(subtitleColor)
                      : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final result = _results[index];

                      final product = (result['product'] is Map)
                          ? (result['product'] as Map)
                          .cast<String, dynamic>()
                          : <String, dynamic>{};

                      final productName =
                      (product['display'] ??
                          product['canonical'] ??
                          'Producto')
                          .toString();

                      final stallName =
                      (result['stallName'] ?? 'Puesto').toString();

                      final addressLabel =
                      (result['addressLabel'] ?? '')
                          .toString()
                          .trim();

                      final distanceLabel = _formatDistance(
                        result['distanceMeters'] as num?,
                      );

                      final isClosest = index == 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isClosest) ...[
                                Container(
                                  margin:
                                  const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusOpen
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                    BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Más cercano',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showLocationSheet(result),
                                      icon:
                                      const Icon(Icons.map_outlined),
                                      label:
                                      const Text('Ver ubicación'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}