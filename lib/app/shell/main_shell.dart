import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/stalls/presentation/pages/stalls_list_page.dart';

/// Índices de las pestañas del shell principal.
class MainShellIndex {
  MainShellIndex._();
  static const int home = 0;
  static const int stalls = 1;
  static const int more = 2;
  static const int profile = 3;
}

/// Shell principal con barra de navegación inferior curva.
/// Contiene: Inicio, Puestos, Más, Perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late final List<Widget> _pages;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    _pages = [
      const _PageWithBottomPadding(child: HomePage()),
      const _PageWithBottomPadding(child: StallsListPage()),
      const _PageWithBottomPadding(child: _MorePlaceholderPage()),
      const _PageWithBottomPadding(child: ProfilePage()),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.blueSurface : Colors.white;
    final buttonBgColor = AppColors.bluePrimary;
    final iconColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;
    final activeIconColor = Colors.white;

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _pages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60,
        color: barColor,
        buttonBackgroundColor: buttonBgColor,
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 350),
        onTap: _onTap,
        items: [
          _NavIcon(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            isActive: _currentIndex == MainShellIndex.home,
            activeColor: activeIconColor,
            inactiveColor: iconColor,
          ),
          _NavIcon(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            isActive: _currentIndex == MainShellIndex.stalls,
            activeColor: activeIconColor,
            inactiveColor: iconColor,
          ),
          _NavIcon(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            isActive: _currentIndex == MainShellIndex.more,
            activeColor: activeIconColor,
            inactiveColor: iconColor,
          ),
          _NavIcon(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            isActive: _currentIndex == MainShellIndex.profile,
            activeColor: activeIconColor,
            inactiveColor: iconColor,
          ),
        ],
      ),
    );
  }
}

/// Evita que el contenido quede oculto tras la barra curva.
class _PageWithBottomPadding extends StatelessWidget {
  const _PageWithBottomPadding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 72), child: child);
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Icon(
      isActive ? activeIcon : icon,
      size: 28,
      color: isActive ? activeColor : inactiveColor,
    );
  }
}

class _MorePlaceholderPage extends StatelessWidget {
  const _MorePlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore_rounded,
                  size: 72,
                  color: AppColors.blueNeon.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 20),
                Text(
                  'Próximamente',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppThemeColors.titleColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Más opciones en camino',
                  style: TextStyle(
                    color: AppThemeColors.subtitleColor(context),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
