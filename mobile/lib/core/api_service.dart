import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/auth/token_store.dart';
import 'app_config.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
}

class ApiService {
  ApiService(this.config, this.tokenStore, {http.Client? client})
    : _client = client ?? http.Client();

  final AppConfig config;
  final TokenStore tokenStore;
  final http.Client _client;
  TokenPair? _tokens;
  Future<void>? _refresh;
  int _sessionVersion = 0;
  void Function()? onSessionExpired;

  bool get hasSession => _tokens != null;

  Future<void> loadSession() async => _tokens = await tokenStore.read();

  Future<void> saveSession(Map<String, dynamic> response) async {
    final pair = _parseTokens(response);
    await tokenStore.write(pair);
    _sessionVersion++;
    _tokens = pair;
  }

  Future<void> clearSession() async {
    _sessionVersion++;
    _tokens = null;
    await tokenStore.clear();
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _request('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) => _request('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    if (!authenticated) return _send(method, path, body: body);
    final version = _sessionVersion;
    if (_tokens == null) {
      throw const ApiException('Lütfen giriş yapın.', statusCode: 401);
    }
    if (_tokens!.needsRefresh) await refreshSession();
    _requireVersion(version);
    final accessToken = _tokens!.accessToken;
    try {
      return await _send(method, path, body: body, accessToken: accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      _requireVersion(version);
      if (_tokens!.accessToken == accessToken) await refreshSession();
      _requireVersion(version);
      try {
        return await _send(
          method,
          path,
          body: body,
          accessToken: _tokens!.accessToken,
        );
      } on ApiException catch (retryError) {
        if (retryError.statusCode == 401) await _expireSession(version);
        rethrow;
      }
    }
  }

  Future<void> refreshSession() {
    final pending = _refresh;
    if (pending != null) return pending;
    final future = _rotateTokens();
    _refresh = future;
    return future.whenComplete(() {
      if (identical(_refresh, future)) _refresh = null;
    });
  }

  Future<void> _rotateTokens() async {
    final version = _sessionVersion;
    final current = _tokens;
    if (current == null) {
      throw const ApiException('Oturum sona erdi.', statusCode: 401);
    }
    try {
      final response = await _send(
        'POST',
        '/api/auth/refresh',
        body: {'refreshToken': current.refreshToken},
      );
      _requireVersion(version);
      final next = _parseTokens(response);
      await tokenStore.write(next);
      _requireVersion(version);
      _tokens = next;
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _expireSession(version);
      rethrow;
    }
  }

  // Build the body after renewal so logout revokes the current refresh token.
  Future<bool> logout() async {
    var revoked = false;
    try {
      if (_refresh != null) await _refresh;
      if (_tokens != null) {
        if (_tokens!.needsRefresh) await refreshSession();
        var current = _tokens!;
        try {
          await _send(
            'POST',
            '/api/auth/logout',
            body: {'refreshToken': current.refreshToken},
            accessToken: current.accessToken,
          );
        } on ApiException catch (error) {
          if (error.statusCode != 401) rethrow;
          await refreshSession();
          current = _tokens!;
          await _send(
            'POST',
            '/api/auth/logout',
            body: {'refreshToken': current.refreshToken},
            accessToken: current.accessToken,
          );
        }
        revoked = true;
      }
    } on ApiException {
      // Network errors must not prevent local logout. The UI reports that the
      // server could not revoke the refresh token.
    } finally {
      await clearSession();
    }
    return revoked;
  }

  void _requireVersion(int version) {
    if (version != _sessionVersion || _tokens == null) {
      throw const ApiException(
        'Oturum sona erdi. Lütfen tekrar giriş yapın.',
        statusCode: 401,
      );
    }
  }

  Future<void> _expireSession(int version) async {
    if (version != _sessionVersion) return;
    await clearSession();
    onSessionExpired?.call();
  }

  TokenPair _parseTokens(Map<String, dynamic> json) {
    try {
      return TokenPair.fromJson(json);
    } on Object {
      throw const ApiException('Sunucu yanıtı okunamadı. Tekrar deneyin.');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final abort = Completer<void>();
    final timer = Timer(AppConfig.requestTimeout, () => abort.complete());
    try {
      final request = http.AbortableRequest(
        method,
        config.apiBaseUrl.resolve(path),
        abortTrigger: abort.future,
      );
      request.followRedirects = false;
      request.headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      Map<String, dynamic> json = {};
      if (response.bodyBytes.isNotEmpty) {
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          } else if (response.statusCode < 400) {
            throw const FormatException();
          }
        } on FormatException {
          if (response.statusCode < 400) {
            throw const ApiException(
              'Sunucu yanıtı okunamadı. Tekrar deneyin.',
            );
          }
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _problem(response.statusCode, json);
      }
      return json;
    } on http.RequestAbortedException {
      throw const ApiException('İstek zaman aşımına uğradı. Tekrar deneyin.');
    } on http.ClientException {
      throw const ApiException(
        'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.',
      );
    } finally {
      timer.cancel();
    }
  }

  ApiException _problem(int status, Map<String, dynamic> json) {
    final fields = <String, String>{};
    final errors = json['errors'];
    if (errors is Map) {
      for (final key in errors.keys) {
        final messages = errors[key];
        if (key is String && messages is List && messages.isNotEmpty) {
          fields[key] = messages.join(' ');
        }
      }
    }
    final message = switch (json['title']) {
      'Invalid email or password' => 'E-posta veya şifre hatalı.',
      'Email already registered' => 'Bu e-posta adresiyle zaten bir hesap var.',
      'Invalid or expired refresh token' =>
        'Oturum sona erdi. Lütfen tekrar giriş yapın.',
      _ => switch (status) {
        400 || 422 => 'Bilgileri kontrol edip tekrar deneyin.',
        401 => 'Oturum sona erdi. Lütfen tekrar giriş yapın.',
        403 => 'Bu işlem için yetkiniz bulunmuyor.',
        409 => 'Bu e-posta adresiyle zaten bir hesap var.',
        429 => 'Çok fazla istek gönderildi. Biraz sonra tekrar deneyin.',
        _ => 'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
      },
    };
    return ApiException(message, statusCode: status, fieldErrors: fields);
  }

  void close() => _client.close();
}
