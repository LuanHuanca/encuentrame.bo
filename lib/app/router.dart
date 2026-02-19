import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/role_selection_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/stalls/presentation/pages/stalls_list_page.dart';

/// Rutas nombradas de la aplicación.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String roleSelection = '/onboarding/role';
  static const String stalls = '/stalls';
}

/// Configuración de rutas para [MaterialApp.routes].
class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomePage(),
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
      case AppRoutes.signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SignupPage(),
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ForgotPasswordPage(),
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfilePage(),
        );
      case AppRoutes.roleSelection:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RoleSelectionPage(),
        );
      case AppRoutes.stalls:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StallsListPage(),
        );
      default:
        return null;
    }
  }
}
