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

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    // VS Code's default Android debug launch must also reach the login screen.
    final useEmulatorDefault =
        configuredUrl.isEmpty &&
        kDebugMode &&
        defaultTargetPlatform == TargetPlatform.android;
    return AppConfig(
      useEmulatorDefault ? androidDevelopmentUrl : configuredUrl,
    );
  }

  static const appName = 'Yapay Zekâ Destekli Sağlık ve Fitness Platformu';
  static const requestTimeout = Duration(seconds: 20);
  static const storageTimeout = Duration(seconds: 5);
  static const androidDevelopmentUrl = 'http://10.0.2.2:5000';
  late final Uri apiBaseUrl;
}
