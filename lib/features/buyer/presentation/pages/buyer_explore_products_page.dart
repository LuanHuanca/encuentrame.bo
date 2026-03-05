import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_section_header.dart';
import '../widgets/buyer_stall_card.dart';
import 'buyer_stall_detail_page.dart';

class BuyerExploreProductsPage extends StatelessWidget {
  const BuyerExploreProductsPage({super.key});

  static const List<Map<String, dynamic>> _mockStalls = [
    {
      'id': 'stall-1',
      'name': 'Puesto Doña Anita',
      'description': 'Salteñas recién horneadas y api caliente.',
      'distance': '120 m',
      'eta': '2 min',
      'tags': ['salteñas', 'desayuno'],
      'rating': 4.8,
      'reviews': 120,
      'isOpen': true,
      'category': 'Desayuno',
    },
    {
      'id': 'stall-2',
      'name': 'Jugos El Frutal',
      'description': 'Jugos naturales y ensaladas de fruta.',
      'distance': '250 m',
      'eta': '4 min',
      'tags': ['jugos', 'fruta'],
      'rating': 4.6,
      'reviews': 89,
      'isOpen': true,
      'category': 'Dulce / Jugos',
    },
    {
      'id': 'stall-3',
      'name': 'Sandwiches El Paso',
      'description': 'Sandwiches de lomito, pollo y hamburguesas.',
      'distance': '430 m',
      'eta': '7 min',
      'tags': ['almuerzo', 'rápido'],
      'rating': 4.4,
      'reviews': 64,
      'isOpen': true,
      'category': 'Almuerzo',
    },
    {
      'id': 'stall-4',
      'name': 'Empanadas Carmelita',
      'description': 'Empanadas de queso fritas y tucumanas.',
      'distance': '600 m',
      'eta': '9 min',
      'tags': ['empanadas', 'desayuno'],
      'rating': 4.7,
      'reviews': 210,
      'isOpen': true,
      'category': 'Desayuno',
    },
    {
      'id': 'stall-5',
      'name': 'Almuerzos Caseros',
      'description': 'Sopa, segundo y refresco. Menú diario.',
      'distance': '800 m',
      'eta': '12 min',
      'tags': ['almuerzo', 'comida'],
      'rating': 4.3,
      'reviews': 45,
      'isOpen': true,
      'category': 'Almuerzo',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    // Agrupamos por categoría
    final Map<String, List<Map<String, dynamic>>> stallsByCategory = {};
    for (var stall in _mockStalls) {
      final cat = stall['category'] as String? ?? 'Otros';
      stallsByCategory.putIfAbsent(cat, () => []).add(stall);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Productos y Categorías')),
      body: BuyerScaffoldGradient(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sigue Explorando',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hemos agrupado estos puestos recomendados por categoría para que encuentres lo que buscas más rápido.',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              
              ...stallsByCategory.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BuyerSectionHeader(title: entry.key),
                      const SizedBox(height: 12),
                      ...entry.value.map((stall) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BuyerStallCard(
                            stall: stall,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BuyerStallDetailPage(
                                    stallId: stall['id'] as String,
                                    stallName: stall['name'] as String,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ],
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
