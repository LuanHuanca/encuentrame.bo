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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HeroCard(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: '¿Qué hace la app?',
                subtitle:
                'Encuéntrame conecta compradores con vendedores ambulantes en tiempo real.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoHighlightCard(
                fillColor: fillColor,
                icon: Icons.travel_explore_rounded,
                iconColor: AppColors.orangeBright,
                title: 'Encuentra productos cerca de ti',
                description:
                'La app detecta tu ubicación y te muestra productos disponibles ordenados del puesto más cercano al más lejano.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoHighlightCard(
                fillColor: fillColor,
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Da visibilidad al comercio informal',
                description:
                'Un vendedor ambulante puede publicar su puesto actual, sus fotos y su inventario para que otras personas lo encuentren fácilmente.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Cómo se usa',
                subtitle: 'Dos flujos simples: comprador y vendedor.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _FlowCard(
                fillColor: fillColor,
                accentColor: AppColors.orangeBright,
                icon: Icons.shopping_bag_rounded,
                title: 'Como comprador',
                steps: const [
                  'Abres la app y se detecta tu ubicación.',
                  'Ves productos cercanos automáticamente, sin escribir nada.',
                  'Si quieres, buscas algo específico como pipocas, api o poleras.',
                  'La app te muestra qué puesto lo tiene y qué tan cerca está.',
                  'Abres el mapa y vas directo al vendedor.',
                ],
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _FlowCard(
                fillColor: fillColor,
                accentColor: AppColors.primary,
                icon: Icons.add_business_rounded,
                title: 'Como vendedor',
                steps: const [
                  'Creas tu puesto una sola vez.',
                  'Cuando llegas a vender, abres tu puesto desde tu ubicación actual.',
                  'Subes una foto del puesto y otra de tus productos.',
                  'Escribes o dictas tu inventario.',
                  'Tus productos quedan visibles para compradores cercanos.',
                ],
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Lo importante del MVP',
                subtitle: 'Simple, funcional y enfocado.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniFeatureCard(
                      fillColor: fillColor,
                      icon: Icons.place_rounded,
                      iconColor: AppColors.primary,
                      title: 'Ubicación real',
                      description: 'El puesto puede cambiar de lugar cada día.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniFeatureCard(
                      fillColor: fillColor,
                      icon: Icons.route_rounded,
                      iconColor: AppColors.orangeBright,
                      title: 'Cercanía',
                      description:
                      'Los resultados se ordenan del más cercano al más lejano.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniFeatureCard(
                      fillColor: fillColor,
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppColors.blueNeon,
                      title: 'Inventario visible',
                      description:
                      'El comprador puede ver qué productos hay disponibles.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniFeatureCard(
                      fillColor: fillColor,
                      icon: Icons.map_rounded,
                      iconColor: AppColors.statusOpen,
                      title: 'Mapa rápido',
                      description:
                      'Puedes abrir la ubicación exacta del vendedor.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: 'Qué no hace todavía',
                subtitle: 'Para no sobrecargar el MVP.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _LimitationsCard(
                fillColor: fillColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 20),
              _ClosingCard(
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.blueNeon.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(
                icon: Icons.near_me_rounded,
                label: 'Tiempo real',
              ),
              _HeroChip(
                icon: Icons.storefront_rounded,
                label: 'Comercio informal',
              ),
              _HeroChip(
                icon: Icons.public_rounded,
                label: 'Más visible',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Encuéntrame',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Una app para encontrar vendedores ambulantes y productos cercanos en el momento exacto en que están vendiendo.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _InfoHighlightCard extends StatelessWidget {
  const _InfoHighlightCard({
    required this.fillColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color fillColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.fillColor,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.steps,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color fillColor;
  final Color accentColor;
  final IconData icon;
  final String title;
  final List<String> steps;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            steps.length,
                (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
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

class _MiniFeatureCard extends StatelessWidget {
  const _MiniFeatureCard({
    required this.fillColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color fillColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitationsCard extends StatelessWidget {
  const _LimitationsCard({
    required this.fillColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color fillColor;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final items = [
      'No hay carrito de compras.',
      'No hay pagos dentro de la app.',
      'No hay pedidos ni reservas.',
      'No busca vender online: busca ayudarte a encontrar al vendedor físico.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.orangeAccent,
                  size: 20,
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
        )
            .toList(),
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({
    required this.fillColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final Color fillColor;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.blueNeon.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En resumen',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encuéntrame ayuda a que el comercio ambulante deje de ser invisible. El comprador encuentra rápido lo que necesita y el vendedor gana visibilidad digital sin complicarse.',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}