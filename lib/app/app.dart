import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Widget raíz de la aplicación. Configura [MaterialApp], tema y rutas.
class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Encuentrame.bo',
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
