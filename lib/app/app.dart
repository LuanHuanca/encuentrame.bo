import 'package:flutter/material.dart';

import '../core/config/amplify_config.dart';
import '../core/config/app_dependencies.dart';

import 'router.dart';
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
    await _loadTheme();
    await AmplifyConfig.configure();

    final signedIn = await AppDependencies.auth.isSignedIn();
    _initialRoute = signedIn ? AppRoutes.home : AppRoutes.login;

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
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = next);
    ThemeModeStorage.save(next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded || _booting) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
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