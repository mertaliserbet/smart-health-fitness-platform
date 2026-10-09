import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/api_service.dart';
import 'user.dart';

enum AuthStatus { checking, signedOut, signedIn, retry }

class AuthService extends ChangeNotifier {
  AuthService(this.api) {
    api.onSessionExpired = () {
      user = null;
      status = AuthStatus.signedOut;
      notice = 'Oturum sona erdi. Lütfen tekrar giriş yapın.';
      notifyListeners();
    };
  }

  final ApiService api;
  AuthStatus status = AuthStatus.checking;
  User? user;
  String? error;
  String? notice;
  bool isBusy = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    error = null;
    notifyListeners();
    try {
      await api.loadSession();
      if (!api.hasSession) {
        status = AuthStatus.signedOut;
      } else {
        user = await _getMe();
        status = AuthStatus.signedIn;
      }
    } on ApiException catch (failure) {
      error = failure.message;
      status = api.hasSession ? AuthStatus.retry : AuthStatus.signedOut;
    } on PlatformException {
      error = 'Güvenli oturum bilgilerine erişilemedi. Tekrar deneyin.';
      status = AuthStatus.retry;
    } on TimeoutException {
      error = 'Cihazdaki oturum bilgileri okunamadı. Tekrar deneyin.';
      status = AuthStatus.retry;
    } on Object catch (failure) {
      debugPrint('Oturum açılışı başarısız: ${failure.runtimeType}');
      error = 'Oturum kontrolü tamamlanamadı. Tekrar deneyin.';
      status = api.hasSession ? AuthStatus.retry : AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await api.post('/api/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await api.saveSession(response);
      user = await _getMe();
      status = AuthStatus.signedIn;
      notice = null;
      notifyListeners();
    } on ApiException catch (failure) {
      if (api.hasSession) {
        status = AuthStatus.retry;
        error = failure.message;
        notifyListeners();
      }
      rethrow;
    } on PlatformException {
      throw const ApiException(
        'Oturum güvenli şekilde saklanamadı. Tekrar deneyin.',
      );
    } on Object {
      throw const ApiException(
        'Giriş tamamlanamadı. Cihazdaki oturum bilgilerini kontrol edip tekrar deneyin.',
      );
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await api.post('/api/auth/register', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<User> _getMe() async {
    final response = await api.get('/api/users/me');
    final User current;
    try {
      current = User.fromJson(response);
    } on Object {
      throw const ApiException(
        'Kullanıcı bilgileri okunamadı. Tekrar deneyin.',
      );
    }
    if (!current.roles.contains('User')) {
      await api.logout();
      throw const ApiException(
        'Bu hesap mobil kullanıcı hesabı değil. Lütfen web panelini kullanın.',
        statusCode: 403,
      );
    }
    return current;
  }

  Future<void> logout() async {
    if (isBusy) return;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final revoked = await api.logout();
      user = null;
      status = AuthStatus.signedOut;
      notice = revoked
          ? 'Çıkış yapıldı.'
          : 'Cihazdan çıkış yapıldı. Sunucuda oturum kapatılamadı; oturum süresi dolana kadar açık kalabilir.';
    } on Object {
      user = null;
      status = AuthStatus.retry;
      error = 'Cihazdaki oturum silinemedi. Çıkış işlemini tekrar deneyin.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    api.onSessionExpired = null;
    api.close();
    super.dispose();
  }
}
