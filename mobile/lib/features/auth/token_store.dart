import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/app_config.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final pair = TokenPair(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
    if (pair.accessToken.isEmpty || pair.refreshToken.isEmpty) {
      throw const FormatException('Empty token');
    }
    return pair;
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get needsRefresh => !expiresAt.isAfter(
    DateTime.now().toUtc().add(const Duration(seconds: 30)),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

class TokenStore {
  TokenStore({required String server, FlutterSecureStorage? storage})
    : _key = 'auth_session_${base64Url.encode(utf8.encode(server))}',
      _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final String _key;
  final FlutterSecureStorage _storage;
  Future<void> _pending = Future.value();

  Future<TokenPair?> read() => _read().timeout(AppConfig.storageTimeout);

  Future<TokenPair?> _read() async {
    await _pending;
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return TokenPair.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  // Keep the token pair in one encrypted value. Serialize writes/deletes so a
  // late refresh cannot restore credentials after logout.
  Future<void> write(TokenPair pair) => _enqueue(
    () => _storage.write(key: _key, value: jsonEncode(pair.toJson())),
  );

  Future<void> clear() => _enqueue(() => _storage.delete(key: _key));

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then((_) {}, onError: (Object _, StackTrace _) {});
    // Keep the native operation in the queue even after the caller times out;
    // a later delete must never be overtaken by an unfinished write.
    return result.timeout(AppConfig.storageTimeout);
  }
}
