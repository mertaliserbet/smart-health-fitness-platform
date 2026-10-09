import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

class SmartHealthFitnessApp extends StatefulWidget {
  const SmartHealthFitnessApp({super.key, required this.auth});
  final AuthService auth;

  @override
  State<SmartHealthFitnessApp> createState() => _SmartHealthFitnessAppState();
}

class _SmartHealthFitnessAppState extends State<SmartHealthFitnessApp> {
  @override
  void initState() {
    super.initState();
    widget.auth.restoreSession();
  }

  @override
  void dispose() {
    widget.auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4D8DFF),
        brightness: Brightness.dark,
        surface: const Color(0xFF121A2B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        errorMaxLines: 3,
      ),
    ),
    home: ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final auth = widget.auth;
        return switch (auth.status) {
          AuthStatus.checking => const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Oturum kontrol ediliyor…'),
                  ],
                ),
              ),
            ),
          ),
          AuthStatus.signedOut => LoginScreen(auth: auth),
          AuthStatus.signedIn => HomeScreen(auth: auth),
          AuthStatus.retry => Scaffold(
            appBar: AppBar(title: const Text('Oturum kontrolü')),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        auth.error ?? 'Oturum doğrulanamadı.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isBusy ? null : auth.restoreSession,
                        child: const Text('Tekrar dene'),
                      ),
                      TextButton(
                        onPressed: auth.isBusy ? null : auth.logout,
                        child: Text(
                          auth.isBusy
                              ? 'Çıkış yapılıyor…'
                              : 'Çıkış yap ve girişe dön',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        };
      },
    ),
  );
}
