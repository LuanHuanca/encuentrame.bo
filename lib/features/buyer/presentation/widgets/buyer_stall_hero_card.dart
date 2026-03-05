import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Encabezado hero del detalle de puesto (imagen, nombre, estado, ubicación).
class BuyerStallHeroCard extends StatelessWidget {
  const BuyerStallHeroCard({
    super.key,
    required this.stallName,
    this.distance = '1.2 km de distancia',
    this.eta = 'A unos minutos caminando',
    this.rating = '4.8',
    this.isOpen = true,
  });

  final String stallName;
  final String distance;
  final String eta;
  final String rating;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -20,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOpen)
                      Chip(
                        label: const Text(
                          'Abierto ahora',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    const Spacer(),
                    Text(
                      stallName.isEmpty ? 'Puesto cercano' : stallName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ubicación aproximada cerca de ti. Más adelante se conectará con geolocalización en tiempo real.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.navigation_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eta,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    distance,
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardOverlayDark
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.orangeBright,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
