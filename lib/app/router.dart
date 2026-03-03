import 'package:flutter/material.dart';

import '../core/config/app_dependencies.dart';

import '../features/auth/presentation/pages/confirm_signup_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';

import '../features/profile/presentation/pages/profile_page.dart';
import 'shell/main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String stalls = '/stalls';

  static const String login = '/login';
  static const String signup = '/signup';
  static const String confirmSignup = '/confirm-signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static const String profile = '/profile';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MainShell(initialIndex: MainShellIndex.home),
        );

      case AppRoutes.stalls:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MainShell(initialIndex: MainShellIndex.stalls),
        );

      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LoginPage(auth: AppDependencies.auth),
        );

      case AppRoutes.signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SignupPage(auth: AppDependencies.auth),
        );

      case AppRoutes.confirmSignup:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ConfirmSignupPage(
            auth: AppDependencies.auth,
            email: (args['email'] as String?) ?? '',
          ),
        );

      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ForgotPasswordPage(auth: AppDependencies.auth),
        );

      case AppRoutes.resetPassword:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ResetPasswordPage(
            auth: AppDependencies.auth,
            email: (args['email'] as String?) ?? '',
          ),
        );

      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfilePage(),
        );

      default:
        return null;
    }
  }
}