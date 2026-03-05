import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/stalls/presentation/pages/my_stalls_page.dart';
import '../../features/buyer/presentation/pages/buyer_explore_page.dart';
import '../../features/buyer/presentation/pages/buyer_home_discover_page.dart';

/// Proporciona información global del shell (modo comprador/vendedor) a la UI.
class MainShellScope extends InheritedWidget {
  const MainShellScope({
    super.key,
    required this.role,
    required this.toggleMode,
    required this.setRole,
    required this.setIndex,
    required super.child,
  });

  /// Rol actual (por ejemplo: BUYER o VENDOR).
  final String role;

  /// Cambia entre modos (comprador / vendedor).
  final VoidCallback toggleMode;

  /// Fija el rol explícitamente (por ejemplo, cambiar directo a BUYER).
  final void Function(String role) setRole;

  /// Cambia el índice actual del bottom navigation.
  final void Function(int index) setIndex;

  static MainShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) {
    return role != oldWidget.role;
  }
}

class MainShellIndex {
  MainShellIndex._();
  static const int home = 0;
  static const int stalls = 1;
  static const int more = 2;
  static const int profile = 3;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Obtiene el [MainShellScope] más cercano en el árbol.
  static MainShellScope? of(BuildContext context) {
    return MainShellScope.of(context);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late PageController _pageController;
  late List<Widget> _pages;
  String _role = 'BUYER';

  void _toggleMode() {
    setState(() {
      _role = _role == 'BUYER' ? 'VENDOR' : 'BUYER';
    });
  }

  void _setRole(String nextRole) {
    if (_role == nextRole) return;
    setState(() {
      _role = nextRole;
      _currentIndex = 0;
      _configurePages();
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentIndex);
    });
  }

  void _setIndex(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
    _configurePages();
    _pageController = PageController(initialPage: _currentIndex);
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
    const activeIconColor = Colors.white;

    return MainShellScope(
      role: _role,
      toggleMode: _toggleMode,
      setRole: _setRole,
      setIndex: _setIndex,
      child: Scaffold(
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
          items: _buildBottomItems(
            role: _role,
            activeIconColor: activeIconColor,
            iconColor: iconColor,
          ),
        ),
      ),
    );
  }

  void _configurePages() {
    if (_role == 'VENDOR') {
      // Vista vendedor: solo puestos y perfil.
      _pages = const [
        _PageWithBottomPadding(child: MyStallsPage()),
        _PageWithBottomPadding(child: ProfilePage()),
      ];
    } else {
      // Vista comprador: inicio (descubrir), explorar, perfil.
      _pages = const [
        _PageWithBottomPadding(child: BuyerHomeDiscoverPage()),
        _PageWithBottomPadding(child: BuyerExplorePage()),
        _PageWithBottomPadding(child: ProfilePage()),
      ];
    }
  }

  List<Widget> _buildBottomItems({
    required String role,
    required Color activeIconColor,
    required Color iconColor,
  }) {
    if (role == 'VENDOR') {
      return [
        _NavIcon(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          isActive: _currentIndex == 0,
          activeColor: activeIconColor,
          inactiveColor: iconColor,
        ),
        _NavIcon(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          isActive: _currentIndex == 1,
          activeColor: activeIconColor,
          inactiveColor: iconColor,
        ),
      ];
    }

    // Vista comprador.
    return [
      _NavIcon(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        isActive: _currentIndex == 0,
        activeColor: activeIconColor,
        inactiveColor: iconColor,
      ),
      _NavIcon(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        isActive: _currentIndex == 1,
        activeColor: activeIconColor,
        inactiveColor: iconColor,
      ),
      _NavIcon(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        isActive: _currentIndex == 2,
        activeColor: activeIconColor,
        inactiveColor: iconColor,
      ),
    ];
  }
}

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

/// Página de la pestaña "Explorar / Más" que depende del rol actual.
// Placeholder eliminado: ya no se usa en el nuevo diseño.
