import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../widgets/buyer_empty_state.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_stall_card.dart';
import 'buyer_stall_detail_page.dart';
import '../../../../app/shell/main_shell.dart';

/// Pantalla de puestos favoritos del comprador.
class BuyerFavoritesPage extends StatefulWidget {
  const BuyerFavoritesPage({super.key});

  @override
  State<BuyerFavoritesPage> createState() => _BuyerFavoritesPageState();
}

class _BuyerFavoritesPageState extends State<BuyerFavoritesPage> {
  static const List<Map<String, dynamic>> _mockFavorites = [
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
  ];

  List<Map<String, dynamic>> _items = List.from(_mockFavorites);

  void _removeFavorite(String id) {
    setState(() {
      _items = _items.where((e) => (e['id'] as String) != id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVendor = MainShell.of(context)?.role == 'VENDOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis favoritos'),
        actions: [
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
        child: _items.isEmpty
            ? BuyerEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Sin favoritos',
                subtitle:
                    'Marca como favoritos los puestos que más te gusten desde Descubrir.',
                actionLabel: 'Explorar puestos',
                onAction: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ve a la pestaña Descubrir')),
                  );
                },
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final stall = _items[index];
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
                      trailing: IconButton(
                        icon: Icon(
                          Icons.favorite_rounded,
                          color: AppColors.orangeBright,
                          size: 22,
                        ),
                        onPressed: () => _removeFavorite(stall['id'] as String),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
