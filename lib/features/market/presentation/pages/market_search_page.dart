import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class MarketSearchPage extends StatefulWidget {
  const MarketSearchPage({super.key});

  @override
  State<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends State<MarketSearchPage> {
  final RestClient _api = RestClient();
  final TextEditingController _queryController = TextEditingController();

  Position? _position;
  bool _gettingLocation = false;

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _results = [];

  bool get _hasLocation => _position != null;

  @override
  void initState() {
    super.initState();
    _ensureLocation();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String _fmtDistance(num? meters) {
    final m = meters?.toDouble();
    if (m == null) return '';
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _ensureLocation() async {
    setState(() {
      _gettingLocation = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Activa el GPS para buscar cerca.');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        setState(() => _error = 'Permiso de ubicación denegado.');
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        setState(() => _error = 'Permiso de ubicación bloqueado. Habilítalo en ajustes.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() => _error = 'No pude obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    final q = _queryController.text.trim();
    if (q.isEmpty) {
      AppSnackbar.info(context, 'Escribe un producto. Ej: zapatos');
      return;
    }

    if (!_hasLocation) {
      AppSnackbar.error(context, 'Falta ubicación. Activa el GPS.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final res = await _api.get(
        '/market/products/search',
        queryParameters: {
          'lat': _position!.latitude.toString(),
          'lng': _position!.longitude.toString(),
          'q': q,
          'radiusKm': '2',
          'limit': '30',
        },
      );

      final list = (res['results'] as List?)?.cast<dynamic>() ?? const [];
      final parsed = list.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() {
        _results = parsed;
        _loading = false;
      });

      if (_results.isEmpty) {
        AppSnackbar.info(context, 'No encontré “$q” cerca. Prueba otra palabra.');
      }
    } on ApiClientException catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyMessages.fromApiError(e);
        _loading = false;
      });
      AppSnackbar.error(context, _error!);
    } catch (e, st) {
      UserFriendlyMessages.logToConsole(e, st);
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyMessages.fromGenericError(e);
        _loading = false;
      });
      AppSnackbar.error(context, _error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.backgroundGradient(context);
    final title = AppThemeColors.titleColor(context);
    final sub = AppThemeColors.subtitleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeColors,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comprar',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Busca productos en puestos abiertos cerca de ti.',
                  style: TextStyle(color: sub, fontSize: 15),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hasLocation
                              ? 'Ubicación lista • ±${_position!.accuracy.toStringAsFixed(0)}m'
                              : (_gettingLocation ? 'Obteniendo ubicación…' : 'Falta ubicación'),
                          style: TextStyle(color: sub, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        onPressed: _gettingLocation ? null : _ensureLocation,
                        icon: const Icon(Icons.my_location),
                        tooltip: 'Actualizar ubicación',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Ej: zapatos',
                    labelText: '¿Qué estás buscando?',
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: (_loading || _gettingLocation) ? null : _search,
                    icon: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.search_rounded),
                    label: Text(_loading ? 'Buscando…' : 'Buscar'),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Expanded(
                  child: _results.isEmpty
                      ? Center(
                    child: Text(
                      'Escribe un producto y busca.',
                      style: TextStyle(color: sub),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final stallName = (r['stallName'] ?? 'Puesto').toString();
                      final distance = _fmtDistance(r['distanceMeters'] as num?);
                      final address = (r['addressLabel'] ?? '').toString().trim();

                      final product = (r['product'] is Map)
                          ? (r['product'] as Map).cast<String, dynamic>()
                          : <String, dynamic>{};

                      final productName =
                      (product['display'] ?? product['canonical'] ?? 'Producto').toString();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: TextStyle(
                                  color: title,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.storefront_outlined, size: 18, color: sub),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      stallName,
                                      style: TextStyle(color: sub, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (distance.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(distance, style: TextStyle(color: sub, fontSize: 13)),
                                  ],
                                ],
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.place_outlined, size: 18, color: sub),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(color: sub, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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