import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/api_service.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/token_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromEnvironment();
    final api = ApiService(
      config,
      TokenStore(server: config.apiBaseUrl.toString()),
    );
    runApp(SmartHealthFitnessApp(auth: AuthService(api)));
  } on Object catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is FormatException
                      ? error.message.toString()
                      : 'Uygulama başlatılamadı. Uygulamayı kapatıp tekrar açın.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
