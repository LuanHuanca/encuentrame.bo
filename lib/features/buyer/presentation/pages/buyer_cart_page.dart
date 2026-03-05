import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../widgets/buyer_empty_state.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_section_header.dart';
import '../../../../app/shell/main_shell.dart';

/// Ítem mock del carrito (puesto + productos).
class _CartItem {
  final String stallId;
  final String stallName;
  final List<Map<String, dynamic>> products;
  _CartItem({
    required this.stallId,
    required this.stallName,
    required this.products,
  });
}

/// Pantalla del carrito del comprador.
class BuyerCartPage extends StatefulWidget {
  const BuyerCartPage({super.key});

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  static final List<_CartItem> _mockCart = [
    _CartItem(
      stallId: 'stall-1',
      stallName: 'Puesto Doña Anita',
      products: [
        {'name': 'Salteña de pollo', 'price': '5 Bs', 'qty': 2},
        {'name': 'Salteña de carne', 'price': '5 Bs', 'qty': 1},
      ],
    ),
  ];

  List<_CartItem> _items = List.from(_mockCart);

  void _removeItem(int stallIndex, int productIndex) {
    setState(() {
      final stall = _items[stallIndex];
      final newProducts = List<Map<String, dynamic>>.from(stall.products)
        ..removeAt(productIndex);
      if (newProducts.isEmpty) {
        _items.removeAt(stallIndex);
      } else {
        _items[stallIndex] = _CartItem(
          stallId: stall.stallId,
          stallName: stall.stallName,
          products: newProducts,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fill = AppThemeColors.inputFill(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final isVendor = MainShell.of(context)?.role == 'VENDOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi carrito'),
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
                icon: Icons.shopping_cart_outlined,
                title: 'Carrito vacío',
                subtitle: 'Agrega productos desde un puesto para verlos aquí.',
                actionLabel: 'Descubrir puestos',
                onAction: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ve a la pestaña Descubrir')),
                  );
                },
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        for (var s = 0; s < _items.length; s++) ...[
                          BuyerSectionHeader(
                            title: _items[s].stallName,
                            fontSize: 16,
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_items[s].products.length, (p) {
                            final prod = _items[s].products[p];
                            final name = prod['name'] as String;
                            final price = prod['price'] as String;
                            final qty = (prod['qty'] as int?) ?? 1;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '$price × $qty',
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: subColor,
                                      size: 22,
                                    ),
                                    onPressed: () => _removeItem(s, p),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                  Container(
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
                              content: Text('Simulación: Ir a pagar'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Ir a pagar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
