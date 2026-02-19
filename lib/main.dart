import 'package:flutter/material.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Amplify.configure(amplifyConfigJson) cuando se añada amplify_flutter
  runApp(const AppWidget());
}
