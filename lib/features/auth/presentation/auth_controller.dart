import 'package:flutter/foundation.dart';

import '../../../core/utils/user_friendly_messages.dart';
import '../data/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;

  bool loading = false;
  String? error;

  Future<T?> _wrap<T>(Future<T> Function() fn) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await fn();
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      error = e.toString();
      notifyListeners();
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> isSignedIn() async {
    final r = await _wrap(() => _repo.isSignedIn());
    return r ?? false;
  }

  Future<bool> signIn(String email, String password) async {
    final r = await _wrap(() async {
      await _repo.signIn(email: email, password: password);
      return true;
    });
    return r ?? false;
  }

  Future<bool> signUp(String email, String password) async {
    final r = await _wrap(() async {
      await _repo.signUp(email: email, password: password);
      return true;
    });
    return r ?? false;
  }

  Future<bool> confirmSignUp(String email, String code) async {
    final r = await _wrap(() async {
      await _repo.confirmSignUp(email: email, code: code);
      return true;
    });
    return r ?? false;
  }

  Future<bool> startResetPassword(String email) async {
    final r = await _wrap(() async {
      await _repo.startResetPassword(email: email);
      return true;
    });
    return r ?? false;
  }

  Future<bool> confirmResetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    final r = await _wrap(() async {
      await _repo.confirmResetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return true;
    });
    return r ?? false;
  }

  Future<void> signOut() async {
    await _wrap(() => _repo.signOut());
  }
}
