import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class MarketHowItWorksPage extends StatelessWidget {
  const MarketHowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleColor = AppThemeColors.titleColor(context);
    final subtitleColor = AppThemeColors.subtitleColor(context);
    final fillColor = AppThemeColors.inputFill(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo funciona'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Encuéntrame conecta compradores con vendedores ambulantes cercanos.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La idea es simple: un vendedor publica su ubicación actual, sus fotos y sus productos. Tú ves qué hay cerca de ti y puedes ubicarlo rápido.',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _InfoCard(
                title: 'Como comprador',
                items: const [
                  'La app muestra productos cercanos automáticamente.',
                  'Los resultados se ordenan del más cercano al más lejano.',
                  'Puedes buscar algo específico o solo explorar lo que hay cerca.',
                  'Puedes abrir el mapa de un resultado para ubicar al vendedor.',
                ],
                fillColor: fillColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Como vendedor',
                items: const [
                  'Abres tu puesto desde tu ubicación actual.',
                  'Subes una foto del puesto y otra de tus productos.',
                  'Dictas o escribes tu inventario.',
                  'Tus productos quedan visibles para compradores cercanos.',
                ],
                fillColor: fillColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Qué hace el MVP',
                items: const [
                  'Mostrar vendedores ambulantes cercanos.',
                  'Listar productos disponibles.',
                  'Permitir encontrar el puesto en el mapa.',
                ],
                fillColor: fillColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Qué no hace todavía',
                items: const [
                  'No hay carrito de compras.',
                  'No hay pagos.',
                  'No hay pedidos ni reservas.',
                ],
                fillColor: fillColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
    required this.fillColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final List<String> items;
  final Color fillColor;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_outline_rounded, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}