import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../widgets/buyer_product_tile.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_stall_hero_card.dart';

class BuyerStallDetailPage extends StatefulWidget {
  const BuyerStallDetailPage({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  final String stallId;
  final String stallName;

  @override
  State<BuyerStallDetailPage> createState() => _BuyerStallDetailPageState();
}

class _BuyerStallDetailPageState extends State<BuyerStallDetailPage> {
  static const List<Map<String, dynamic>> _mockProducts = [
    {
      'name': 'Salteña de pollo',
      'price': '5 Bs',
      'description': 'Salteña tradicional de pollo con papa y ají suave.',
      'tag': 'salteñas',
    },
    {
      'name': 'Salteña de carne',
      'price': '5 Bs',
      'description': 'Carne jugosa con ligero picante.',
      'tag': 'salteñas',
    },
    {
      'name': 'Jugo de naranja',
      'price': '7 Bs',
      'description': 'Naranja natural, sin azúcar añadida.',
      'tag': 'jugos',
    },
    {
      'name': 'Ensalada de frutas',
      'price': '10 Bs',
      'description': 'Frutas de temporada con yogurt o jugo a elección.',
      'tag': 'fruta',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stallName.isEmpty ? 'Puesto' : widget.stallName),
      ),
      body: BuyerScaffoldGradient(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BuyerStallHeroCard(stallName: widget.stallName),
              const SizedBox(height: 24),
              Text(
                'Productos del puesto',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._mockProducts.map(
                (p) => BuyerProductTile(
                  name: p['name'] as String,
                  price: p['price'] as String,
                  description: p['description'] as String,
                  tag: p['tag'] as String,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Próximos pasos',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Desde aquí más adelante podrás seleccionar productos, ver el mapa exacto del puesto y confirmar tu compra usando servicios de AWS (geolocalización, pagos, etc.).',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Simulación: Iniciando pedido...'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Ir a pagar (Mock)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
