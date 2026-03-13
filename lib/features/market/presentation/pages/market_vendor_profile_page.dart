import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/user_friendly_messages.dart';
import '../../../../shared/api/rest_client.dart';

class MarketVendorProfilePage extends StatefulWidget {
  const MarketVendorProfilePage({
    super.key,
    required this.vendorUserId,
    this.userLat,
    this.userLng,
  });

  final String vendorUserId;
  final double? userLat;
  final double? userLng;

  @override
  State<MarketVendorProfilePage> createState() =>
      _MarketVendorProfilePageState();
}

class _MarketVendorProfilePageState extends State<MarketVendorProfilePage> {
  final RestClient _api = RestClient();

  bool _loading = true;
  String? _errorMessage;

  Map<String, dynamic>? _vendor;
  List<Map<String, dynamic>> _stalls = [];
  String? _vendorPhotoUrl;

  final Map<String, Future<String?>> _storageUrlCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _getStorageUrl(String key) {
    final trimmedKey = key.trim();

    if (trimmedKey.isEmpty) {
      return Future.value(null);
    }

    return _storageUrlCache.putIfAbsent(trimmedKey, () async {
      try {
        final response = await Amplify.Storage.getUrl(
          path: StoragePath.fromString(trimmedKey),
        ).result;

        return response.url.toString();
      } catch (_) {
        return null;
      }
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sin fecha';

    try {
      final date = DateTime.parse(iso).toLocal();

      String twoDigits(int value) => value.toString().padLeft(2, '0');

      return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get(
        '/market/vendors/${widget.vendorUserId}',
      );

      _vendor = (response['vendor'] as Map?)?.cast<String, dynamic>();

      final rawStalls =
          (response['stalls'] as List?)?.cast<dynamic>() ?? const [];

      _stalls = rawStalls
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      final vendorPhotoKey = (_vendor?['photoKey'] ?? '').toString().trim();

      if (vendorPhotoKey.isNotEmpty) {
        _vendorPhotoUrl = await _getStorageUrl(vendorPhotoKey);
      }
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

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendedor')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 52,
                  color: subtitleColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No se pudo cargar el vendedor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 18),
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

    final vendor = _vendor!;
    final displayName = (vendor['displayName'] ?? 'Vendedor').toString();
    final publicTagline = (vendor['publicTagline'] ?? '').toString().trim();
    final city = (vendor['city'] ?? '').toString().trim();
    final zone = (vendor['zone'] ?? '').toString().trim();
    final stallCount = (vendor['stallCount'] ?? 0).toString();
    final sellerSince = _formatDate(vendor['sellerSince']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del vendedor'),
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
            padding: const EdgeInsets.all(16),
            children: [
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
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      if (_vendorPhotoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            _vendorPhotoUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayName.trim().isEmpty
                                ? 'V'
                                : displayName.trim().characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (publicTagline.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                publicTagline,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (city.isNotEmpty || zone.isNotEmpty)
                                  _Tag(
                                    label: [
                                      if (city.isNotEmpty) city,
                                      if (zone.isNotEmpty) zone,
                                    ].join(' · '),
                                    color: AppColors.blueNeon,
                                  ),
                                _Tag(
                                  label: '$stallCount puesto(s)',
                                  color: AppColors.orangeAccent,
                                ),
                                _Tag(
                                  label: 'Vende desde $sellerSince',
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Puestos publicados',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _stalls.length.toString(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_stalls.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeColors.inputFill(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Este vendedor todavía no tiene puestos visibles.',
                    style: TextStyle(color: subtitleColor),
                  ),
                )
              else
                ..._stalls.map(
                      (stall) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VendorStallCard(
                      stall: stall,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      futureFactory: _getStorageUrl,
                      onTap: () {
                        final stallId = (stall['stallId'] ?? '').toString();
                        if (stallId.isEmpty) return;

                        Navigator.pop(context, stallId);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorStallCard extends StatelessWidget {
  const _VendorStallCard({
    required this.stall,
    required this.titleColor,
    required this.subtitleColor,
    required this.futureFactory,
    required this.onTap,
  });

  final Map<String, dynamic> stall;
  final Color titleColor;
  final Color subtitleColor;
  final Future<String?> Function(String key) futureFactory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stallName = (stall['name'] ?? 'Puesto').toString();
    final category = (stall['category'] ?? '').toString().trim();
    final description = (stall['description'] ?? '').toString().trim();
    final coverPhotoKey = (stall['coverPhotoKey'] ?? '').toString().trim();
    final isOpen = stall['isOpen'] == true;
    final updatedAt = (stall['updatedAt'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeColors.inputFill(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _VendorStallImage(
                  storageKey: coverPhotoKey,
                  futureFactory: futureFactory,
                  fallbackText:
                  stallName.trim().isEmpty ? 'P' : stallName[0].toUpperCase(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stallName,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (category.isNotEmpty)
                            _Tag(
                              label: category,
                              color: AppColors.blueNeon,
                            ),
                          _Tag(
                            label: isOpen ? 'Abierto' : 'Cerrado',
                            color: isOpen
                                ? AppColors.statusOpen
                                : AppColors.statusClosed,
                          ),
                          if (updatedAt.isNotEmpty)
                            _Tag(
                              label: 'Act. ${updatedAt.split('T').first}',
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorStallImage extends StatelessWidget {
  const _VendorStallImage({
    required this.storageKey,
    required this.futureFactory,
    required this.fallbackText,
  });

  final String storageKey;
  final Future<String?> Function(String key) futureFactory;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    if (storageKey.trim().isEmpty) {
      return Container(
        width: 74,
        height: 74,
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
          fallbackText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: futureFactory(storageKey),
      builder: (context, snapshot) {
        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return Container(
            width: 74,
            height: 74,
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
              fallbackText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            width: 74,
            height: 74,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}