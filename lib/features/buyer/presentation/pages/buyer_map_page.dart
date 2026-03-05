import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../widgets/buyer_scaffold_gradient.dart';
import '../widgets/buyer_stall_card.dart';
import 'buyer_stall_detail_page.dart';

class BuyerMapPage extends StatefulWidget {
  const BuyerMapPage({super.key});

  @override
  State<BuyerMapPage> createState() => _BuyerMapPageState();
}

class _BuyerMapPageState extends State<BuyerMapPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Mocks de puestos con colores asociados a sus "pines" en el mapa
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
      'color': AppColors.orangeBright, // Naranja
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
      'color': AppColors.primaryLight, // Cambiado el AppColors.greenAccent
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
      'color': AppColors.blueNeon, // Azul
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _mockStalls.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final fill = AppThemeColors.inputFill(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Puestos')),
      body: BuyerScaffoldGradient(
        child: Column(
          children: [
            // Vista Previa de "Mapa"
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Fondo que simula el mapa
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey.withValues(alpha: 0.2), // Fondo base
                    child: CustomPaint(
                      painter: _GridPainter(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  
                  // "Pines" del mapa falsos dispersos
                  Positioned(
                    top: 80,
                    left: 90,
                    child: _MapPin(
                      color: _mockStalls[0]['color'] as Color,
                      onTap: () => _tabController.animateTo(0),
                    ),
                  ),
                  Positioned(
                    bottom: 120,
                    right: 80,
                    child: _MapPin(
                      color: _mockStalls[1]['color'] as Color,
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ),
                  Positioned(
                    top: 150,
                    right: 120,
                    child: _MapPin(
                      color: _mockStalls[2]['color'] as Color,
                      onTap: () => _tabController.animateTo(2),
                    ),
                  ),
                  
                  // Información "Toca un pin"
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_rounded, color: AppColors.blueNeon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Toca un puesto en el mapa',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Lista Paginada de puestos debajo
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: TabBarView(
                    controller: _tabController,
                    children: _mockStalls.map((stall) {
                      final badgeColor = stall['color'] as Color;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Container(
                              height: 6,
                              width: 60,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
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
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

// CustomPainter para pintar una grilla y simular calles/mapa
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    const gridSize = 60.0;
    
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: Colors.transparent, size: 2), // Espaciador visual para el margin
          Icon(Icons.arrow_drop_down_rounded, color: color, size: 36),
        ],
      ),
    );
  }
}
