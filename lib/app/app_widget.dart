import 'package:flutter/material.dart';

import '../core/config/amplify_config.dart';
import '../core/config/app_dependencies.dart';
import 'router.dart';
import 'splash/splash_screen.dart';
import 'theme.dart';
import 'theme_mode_scope.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _themeLoaded = false;

  bool _booting = true;
  String _initialRoute = AppRoutes.login;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    const splashMinDuration = Duration(seconds: 2);
    final stopwatch = Stopwatch()..start();

    await _loadTheme();
    await AmplifyConfig.configure();

    final signedIn = await AppDependencies.auth.isSignedIn();
    _initialRoute = signedIn ? AppRoutes.home : AppRoutes.login;

    stopwatch.stop();

    final remainingMilliseconds =
        splashMinDuration.inMilliseconds - stopwatch.elapsedMilliseconds;

    if (remainingMilliseconds > 0 && mounted) {
      await Future.delayed(Duration(milliseconds: remainingMilliseconds));
    }

    if (mounted) {
      setState(() => _booting = false);
    }
  }

  Future<void> _loadTheme() async {
    final themeMode = await ThemeModeStorage.load();

    if (!mounted) return;

    setState(() {
      _themeMode = themeMode;
      _themeLoaded = true;
    });
  }

  void _toggleTheme() {
    final nextThemeMode =
    _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    _setThemeMode(nextThemeMode);
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
    ThemeModeStorage.save(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded || _booting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        home: const SplashScreen(),
      );
    }

    return ThemeModeScope(
      themeMode: _themeMode,
      onToggleTheme: _toggleTheme,
      onSetThemeMode: _setThemeMode,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Encuentrame.bo',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        initialRoute: _initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}