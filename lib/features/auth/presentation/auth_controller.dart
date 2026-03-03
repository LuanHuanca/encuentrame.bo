import 'package:flutter/foundation.dart';

import '../../../core/utils/user_friendly_messages.dart';
import '../data/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;

  bool loading = false;
  String? error;

  Future<T?> _run<T>(Future<T> Function() task) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      return await task();
    } catch (e, stackTrace) {
      UserFriendlyMessages.logToConsole(e, stackTrace);
      error = e.toString();
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> isSignedIn() async {
    final result = await _run(() => _repo.isSignedIn());
    return result ?? false;
  }

  Future<bool> signIn(String email, String password) async {
    final result = await _run(() async {
      await _repo.signIn(email: email.trim(), password: password);
      return true;
    });
    return result ?? false;
  }

  Future<bool> signUp(String email, String password) async {
    final result = await _run(() async {
      await _repo.signUp(email: email.trim(), password: password);
      return true;
    });
    return result ?? false;
  }

  Future<bool> confirmSignUp(String email, String code) async {
    final result = await _run(() async {
      await _repo.confirmSignUp(email: email.trim(), code: code.trim());
      return true;
    });
    return result ?? false;
  }

  Future<bool> startResetPassword(String email) async {
    final result = await _run(() async {
      await _repo.startResetPassword(email: email.trim());
      return true;
    });
    return result ?? false;
  }

  Future<bool> confirmResetPassword(
      String email,
      String code,
      String newPassword,
      ) async {
    final result = await _run(() async {
      await _repo.confirmResetPassword(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
      );
      return true;
    });
    return result ?? false;
  }

  Future<void> signOut() async {
    await _run(() => _repo.signOut());
  }
}