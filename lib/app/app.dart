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
    final splashMinDuration = const Duration(seconds: 2);
    final stopwatch = Stopwatch()..start();

    await _loadTheme();
    await AmplifyConfig.configure();

    final signedIn = await AppDependencies.auth.isSignedIn();
    _initialRoute = signedIn ? AppRoutes.home : AppRoutes.login;

    stopwatch.stop();
    final remaining =
        splashMinDuration.inMilliseconds - stopwatch.elapsedMilliseconds;
    if (remaining > 0 && mounted) {
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (mounted) {
      setState(() => _booting = false);
    }
  }

  Future<void> _loadTheme() async {
    final mode = await ThemeModeStorage.load();
    if (mounted) {
      setState(() {
        _themeMode = mode;
        _themeLoaded = true;
      });
    }
  }

  void _toggleTheme() {
    final next = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() => _themeMode = next);
    ThemeModeStorage.save(next);
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
