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
              const _HeroCard(),
              const SizedBox(height: 20),
              _SectionTitle(
                title: '¿Qué es Encuéntrame?',
                subtitle:
                'Una app pensada para ayudarte a encontrar puestos y productos cercanos de forma rápida, simple y visual.',
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
                'La app detecta tu ubicación y te muestra opciones reales que están disponibles alrededor tuyo en ese momento.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _InfoHighlightCard(
                fillColor: fillColor,
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Da visibilidad a los puestos',
                description:
                'Los vendedores pueden mostrar su puesto, sus productos y su ubicación actual para que más personas los encuentren fácilmente.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: '¿Cómo se usa?',
                subtitle:
                'La misma cuenta te permite usar la app de dos maneras, según lo que necesites en el momento.',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _FlowCard(
                fillColor: fillColor,
                accentColor: AppColors.orangeBright,
                icon: Icons.shopping_bag_rounded,
                title: 'Modo comprador',
                steps: const [
                  'Abres la app y se detecta tu ubicación actual.',
                  'Ves productos y puestos cercanos automáticamente.',
                  'Puedes buscar algo específico si quieres encontrarlo más rápido.',
                  'Tocas un resultado y revisas más información del puesto.',
                  'Usas el mapa para ubicarte y llegar al lugar.',
                ],
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 12),
              _FlowCard(
                fillColor: fillColor,
                accentColor: AppColors.primary,
                icon: Icons.add_business_rounded,
                title: 'Modo vendedor',
                steps: const [
                  'Creas tu puesto una sola vez.',
                  'Cuando empiezas a vender, publicas tu ubicación actual.',
                  'Subes fotos de tu puesto y de tus productos.',
                  'Agregas tu inventario por texto o voz.',
                  'Tus productos quedan visibles para compradores cercanos.',
                ],
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Lo más importante',
                subtitle:
                'Todo está pensado para que la experiencia sea rápida, clara y útil.',
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
                      title: 'Ubicación actual',
                      description:
                      'Los puestos pueden aparecer justo donde están vendiendo en ese momento.',
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
                      title: 'Más cerca primero',
                      description:
                      'Los resultados se ordenan para que encuentres antes lo que te queda más próximo.',
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
                      title: 'Productos visibles',
                      description:
                      'Puedes ver mejor qué está ofreciendo cada puesto antes de moverte.',
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
                      'La ubicación del puesto se muestra de forma visual y fácil de entender.',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
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
  const _HeroCard();

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
                label: 'Ubicación en tiempo real',
              ),
              _HeroChip(
                icon: Icons.storefront_rounded,
                label: 'Puestos cercanos',
              ),
              _HeroChip(
                icon: Icons.shopping_bag_rounded,
                label: 'Compra y vende',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
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
            'Descubre productos cercanos y encuentra puestos reales desde una experiencia simple, visual y útil.',
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
      height: 172,
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
            'Encuéntrame te ayuda a descubrir productos y puestos cercanos de manera más rápida, clara y visual. Es una experiencia pensada para conectar mejor a quienes buscan comprar con quienes están vendiendo en el momento exacto.',
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