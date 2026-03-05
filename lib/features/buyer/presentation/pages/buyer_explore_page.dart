import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../widgets/buyer_explore_card.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import 'buyer_home_discover_page.dart';
import 'buyer_explore_products_page.dart';
import 'buyer_map_page.dart';

class BuyerExplorePage extends StatelessWidget {
  const BuyerExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Explorar como comprador')),
      body: BuyerScaffoldGradient(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Explorar Encuéntrame',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Descubre nuevos puestos, explora por categorías y revisa tus favoritos y compras recientes.',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              BuyerExploreCard(
                icon: Icons.explore_rounded,
                iconBg: AppColors.primary,
                title: 'Descubrir puestos cercanos',
                subtitle:
                    'Ver una lista de puestos cerca de tu ubicación (por ahora estático, luego vía geolocalización).',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuyerHomeDiscoverPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BuyerExploreCard(
                icon: Icons.shopping_bag_outlined,
                iconBg: AppColors.orangeBright,
                title: 'Seguir explorando productos',
                subtitle:
                    'Próximamente: ver recomendaciones personalizadas según lo que compres.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuyerExploreProductsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BuyerExploreCard(
                icon: Icons.map_outlined,
                iconBg: AppColors.blueNeon,
                title: 'Mapa de puestos',
                subtitle:
                    'Más adelante aquí verás un mapa con los puestos abiertos usando servicios de mapas/GPS de AWS.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuyerMapPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
