import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig(String baseUrl, {bool allowHttp = kDebugMode}) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/') ||
        (!allowHttp && uri.scheme != 'https')) {
      throw const FormatException(
        'API adresi geçersiz. API_BASE_URL ayarını sunucu adresiyle belirtin. '
        'Release ve profile sürümlerinde HTTPS kullanın.',
      );
    }
    apiBaseUrl = uri.replace(path: '/');
  }

  factory AppConfig.fromEnvironment() =>
      AppConfig(const String.fromEnvironment('API_BASE_URL'));

  static const appName = 'Yapay Zekâ Destekli Sağlık ve Fitness Platformu';
  static const requestTimeout = Duration(seconds: 20);
  late final Uri apiBaseUrl;
}
