import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

import '../../features/market/presentation/pages/market_search_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/stalls/presentation/pages/my_stalls_page.dart';
import '../theme.dart';

class MainShellMode {
  MainShellMode._();

  static const String buyer = 'BUYER';
  static const String vendor = 'VENDOR';
}

class MainShellScope extends InheritedWidget {
  const MainShellScope({
    super.key,
    required this.mode,
    required this.currentIndex,
    required this.toggleMode,
    required this.setMode,
    required this.setIndex,
    required super.child,
  });

  final String mode;
  final int currentIndex;
  final VoidCallback toggleMode;
  final ValueChanged<String> setMode;
  final ValueChanged<int> setIndex;

  String get role => mode;

  bool get isBuyer => mode == MainShellMode.buyer;
  bool get isVendor => mode == MainShellMode.vendor;

  void switchToBuyer() => setMode(MainShellMode.buyer);
  void switchToVendor() => setMode(MainShellMode.vendor);

  static MainShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) {
    return mode != oldWidget.mode || currentIndex != oldWidget.currentIndex;
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialMode = MainShellMode.buyer,
    this.initialIndex = 0,
  });

  final String initialMode;
  final int initialIndex;

  static MainShellScope? of(BuildContext context) {
    return MainShellScope.of(context);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late String _mode;
  late int _currentIndex;
  late final PageController _pageController;

  List<Widget> get _pages => _buildPages(_mode);

  @override
  void initState() {
    super.initState();

    _mode = widget.initialMode == MainShellMode.vendor
        ? MainShellMode.vendor
        : MainShellMode.buyer;

    final safeIndex = widget.initialIndex.clamp(0, _buildPages(_mode).length - 1);
    _currentIndex = safeIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _setMode(_mode == MainShellMode.buyer
        ? MainShellMode.vendor
        : MainShellMode.buyer);
  }

  void _setMode(String nextMode) {
    if (nextMode != MainShellMode.buyer && nextMode != MainShellMode.vendor) {
      return;
    }

    if (_mode == nextMode) return;

    setState(() {
      _mode = nextMode;
      _currentIndex = 0;
    });

    _pageController.jumpToPage(0);
  }

  void _setIndex(int index) {
    final pagesLength = _pages.length;
    if (index < 0 || index >= pagesLength) return;
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  List<Widget> _buildPages(String mode) {
    if (mode == MainShellMode.vendor) {
      return [
        const _PageWithBottomPadding(child: MyStallsPage()),
        const _PageWithBottomPadding(child: ProfilePage()),
      ];
    }

    return [
      const _PageWithBottomPadding(child: MarketSearchPage()),
      const _PageWithBottomPadding(child: ProfilePage()),
    ];
  }

  List<Widget> _buildBottomItems({
    required Color activeIconColor,
    required Color inactiveIconColor,
  }) {
    if (_mode == MainShellMode.vendor) {
      return [
        _NavIcon(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          isActive: _currentIndex == 0,
          activeColor: activeIconColor,
          inactiveColor: inactiveIconColor,
        ),
        _NavIcon(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          isActive: _currentIndex == 1,
          activeColor: activeIconColor,
          inactiveColor: inactiveIconColor,
        ),
      ];
    }

    return [
      _NavIcon(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        isActive: _currentIndex == 0,
        activeColor: activeIconColor,
        inactiveColor: inactiveIconColor,
      ),
      _NavIcon(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        isActive: _currentIndex == 1,
        activeColor: activeIconColor,
        inactiveColor: inactiveIconColor,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.blueSurface : Colors.white;
    final inactiveIconColor =
    isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return MainShellScope(
      mode: _mode,
      currentIndex: _currentIndex,
      toggleMode: _toggleMode,
      setMode: _setMode,
      setIndex: _setIndex,
      child: Scaffold(
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
            }
          },
          children: _pages,
        ),
        bottomNavigationBar: CurvedNavigationBar(
          index: _currentIndex,
          height: 60,
          color: barColor,
          buttonBackgroundColor: AppColors.bluePrimary,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOutCubic,
          animationDuration: const Duration(milliseconds: 320),
          onTap: _setIndex,
          items: _buildBottomItems(
            activeIconColor: Colors.white,
            inactiveIconColor: inactiveIconColor,
          ),
        ),
      ),
    );
  }
}

class _PageWithBottomPadding extends StatelessWidget {
  const _PageWithBottomPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: child,
    );
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