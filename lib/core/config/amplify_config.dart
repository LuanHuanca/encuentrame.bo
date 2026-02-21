import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';

import '../../amplifyconfiguration.dart';

class AmplifyConfig {
  AmplifyConfig._();

  static bool _configured = false;

  static Future<void> configure() async {
    if (_configured) return;

    try {
      await Amplify.addPlugins([
        AmplifyAuthCognito(),
        AmplifyAPI(),
        AmplifyStorageS3(),
      ]);
      await Amplify.configure(amplifyconfig);
      _configured = true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
    }
  }
}