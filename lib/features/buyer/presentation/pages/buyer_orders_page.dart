import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../widgets/buyer_empty_state.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_section_header.dart';
import '../../../../app/shell/main_shell.dart';

/// Tarjeta de pedido para la lista de pedidos.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.stallName,
    required this.status,
    required this.total,
    required this.date,
    required this.onTap,
  });

  final String orderId;
  final String stallName;
  final String status;
  final String total;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = AppThemeColors.inputFill(context);
    final titleColor = AppThemeColors.titleColor(context);
    final subColor = AppThemeColors.subtitleColor(context);
    final isDelivered = status.toLowerCase().contains('entregado');
    final isPending =
        status.toLowerCase().contains('pendiente') ||
        status.toLowerCase().contains('camino');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(color: subColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDelivered
                          ? AppColors.statusOpen.withValues(alpha: 0.15)
                          : isPending
                          ? AppColors.orangeBright.withValues(alpha: 0.15)
                          : subColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDelivered
                            ? AppColors.statusOpen
                            : isPending
                            ? AppColors.orangeBright
                            : subColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                  Text(
                    total,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de pedidos del comprador.
class BuyerOrdersPage extends StatelessWidget {
  const BuyerOrdersPage({super.key});

  static const List<Map<String, dynamic>> _mockOrders = [
    {
      'id': 'ord-1',
      'stallName': 'Puesto Doña Anita',
      'status': 'Entregado',
      'total': '15 Bs',
      'date': 'Hoy, 10:30',
    },
    {
      'id': 'ord-2',
      'stallName': 'Jugos El Frutal',
      'status': 'En camino',
      'total': '22 Bs',
      'date': 'Ayer, 14:00',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isVendor = MainShell.of(context)?.role == 'VENDOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
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
        child: _mockOrders.isEmpty
            ? BuyerEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin pedidos',
                subtitle: 'Cuando hagas un pedido aparecerá aquí.',
                actionLabel: 'Descubrir puestos',
                onAction: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ve a la pestaña Descubrir')),
                  );
                },
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  BuyerSectionHeader(title: 'Historial', fontSize: 18),
                  const SizedBox(height: 16),
                  ..._mockOrders.map(
                    (o) => _OrderCard(
                      orderId: o['id'] as String,
                      stallName: o['stallName'] as String,
                      status: o['status'] as String,
                      total: o['total'] as String,
                      date: o['date'] as String,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Detalle del pedido ${o['id']} (próximamente)',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
