import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Tarjeta de producto para listados del puesto (nombre, precio, descripción, agregar al carrito).
class BuyerProductTile extends StatefulWidget {
  const BuyerProductTile({
    super.key,
    required this.name,
    required this.price,
    required this.description,
    required this.tag,
    this.onAddToCart,
    this.onRemoveFromCart,
  });

  final String name;
  final String price;
  final String description;
  final String tag;
  final VoidCallback? onAddToCart;
  final VoidCallback? onRemoveFromCart;

  @override
  State<BuyerProductTile> createState() => _BuyerProductTileState();
}

class _BuyerProductTileState extends State<BuyerProductTile> {
  bool _addedToCart = false;

  @override
  Widget build(BuildContext context) {
    final fill = AppThemeColors.inputFill(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.orangeSoft.withValues(alpha: 0.4),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.orangeAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.price,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.description,
                  style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.local_offer_outlined, size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.tag,
                      style: TextStyle(color: subColor, fontSize: 12),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _addedToCart
                          ? FilledButton.icon(
                              key: const ValueKey('added'),
                              onPressed: () {
                                setState(() => _addedToCart = false);
                                widget.onRemoveFromCart?.call();
                              },
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text(
                                'Agregado',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.statusOpen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 0),
                              ),
                            )
                          : FilledButton.tonalIcon(
                              key: const ValueKey('add'),
                              onPressed: () {
                                setState(() => _addedToCart = true);
                                widget.onAddToCart?.call();
                              },
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Agregar',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 0),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
