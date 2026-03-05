import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../widgets/buyer_filter_chip.dart';
import '../widgets/buyer_section_header.dart';
import '../widgets/buyer_stall_card.dart';
import '../widgets/buyer_search_bar.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/promo_banner_card.dart';
import 'buyer_stall_detail_page.dart';
import '../../../../app/shell/main_shell.dart';
import 'buyer_explore_page.dart';

class BuyerHomeDiscoverPage extends StatefulWidget {
  const BuyerHomeDiscoverPage({super.key});

  @override
  State<BuyerHomeDiscoverPage> createState() => _BuyerHomeDiscoverPageState();
}

class _BuyerHomeDiscoverPageState extends State<BuyerHomeDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'cerca';

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
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    final query = _searchController.text.toLowerCase().trim();
    final filtered = _mockStalls.where((stall) {
      final name = (stall['name'] ?? '').toString().toLowerCase();
      final desc = (stall['description'] ?? '').toString().toLowerCase();
      final tags =
          (stall['tags'] as List?)?.map((t) => t.toString().toLowerCase()) ??
          const Iterable<String>.empty();

      final matchesQuery =
          query.isEmpty ||
          name.contains(query) ||
          desc.contains(query) ||
          tags.any((t) => t.contains(query));

      if (!matchesQuery) return false;

      if (_selectedFilter == 'cerca') return true;
      if (_selectedFilter == 'desayuno') {
        return tags.contains('desayuno');
      }
      if (_selectedFilter == 'almuerzo') {
        return tags.contains('almuerzo') || tags.contains('rápido');
      }
      if (_selectedFilter == 'dulce') {
        return tags.contains('fruta');
      }
      return true;
    }).toList();

    final isVendor = MainShell.of(context)?.role == 'VENDOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descubrir puestos'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyerExplorePage()),
              );
            },
            icon: const Icon(Icons.explore_rounded, size: 20),
            label: const Text('Explorar'),
          ),
          if (isVendor)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.tonalIcon(
                onPressed: () => MainShell.of(context)?.toggleMode(),
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: const Text(
                  'Modo Vendedor',
                  style: TextStyle(fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
        ],
      ),
      body: BuyerScaffoldGradient(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Explora puestos cercanos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usa la búsqueda y los filtros para encontrar algo rico cerca de ti.',
                      style: TextStyle(color: subColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    BuyerSearchBar(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    BuyerSectionHeader(title: 'Ofertas de Hoy'),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          PromoBannerCard(
                            title: '20% en Salteñas',
                            subtitle: 'Puesto Doña Anita',
                            color: AppColors.orangeBright,
                            icon: Icons.local_fire_department_rounded,
                          ),
                          PromoBannerCard(
                            title: 'Envío Gratis',
                            subtitle: 'Jugos El Frutal',
                            color: AppColors.primaryLight,
                            icon: Icons.local_shipping_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    BuyerSectionHeader(title: 'Categorías'),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          BuyerFilterChip(
                            label: 'Cerca de mí',
                            value: 'cerca',
                            groupValue: _selectedFilter,
                            icon: Icons.near_me_rounded,
                            onSelected: (v) =>
                                setState(() => _selectedFilter = v),
                          ),
                          BuyerFilterChip(
                            label: 'Desayuno',
                            value: 'desayuno',
                            groupValue: _selectedFilter,
                            icon: Icons.wb_sunny_rounded,
                            onSelected: (v) =>
                                setState(() => _selectedFilter = v),
                          ),
                          BuyerFilterChip(
                            label: 'Almuerzo',
                            value: 'almuerzo',
                            groupValue: _selectedFilter,
                            icon: Icons.lunch_dining_rounded,
                            onSelected: (v) =>
                                setState(() => _selectedFilter = v),
                          ),
                          BuyerFilterChip(
                            label: 'Dulce / jugos',
                            value: 'dulce',
                            groupValue: _selectedFilter,
                            icon: Icons.local_drink_rounded,
                            onSelected: (v) =>
                                setState(() => _selectedFilter = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    BuyerSectionHeader(title: 'Puestos Recomendados'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final stall = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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
                }, childCount: filtered.length),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }
}
