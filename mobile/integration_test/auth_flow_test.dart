import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_form.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';
import 'package:smart_health_fitness_mobile/features/navigation/app_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register → login → me → secure restore → refresh → logout', (
    tester,
  ) async {
    // Simulate the keyboard only. HTTP and secure storage use the real device.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    // Run only against the disposable backend fixture from tool/auth_smoke.ps1.
    const fixture = bool.fromEnvironment('AUTH_TEST_FIXTURE');
    expect(
      fixture,
      isTrue,
      reason: 'Use the isolated fixture; never a real user database.',
    );
    final config = AppConfig.fromEnvironment();
    final store = TokenStore(server: config.apiBaseUrl.toString());
    await store.clear();
    final email =
        'mobile-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'Mobile-Test-Password123!';
    final client = AuthContractClient(email, password);
    final api = ApiService(config, store, client: client);
    final auth = AuthService(api);

    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kayıt Ol'));
    await tester.pumpAndSettle();
    final registerFields = find.byType(TextFormField);
    await tester.enterText(registerFields.at(0), 'Mobil');
    await tester.enterText(registerFields.at(1), 'Test');
    await tester.enterText(registerFields.at(2), email);
    await tester.enterText(registerFields.at(3), password);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Hesap Oluştur'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap Oluştur'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 45),
    );
    expect(
      find.text('Hesabınız oluşturuldu. Şimdi giriş yapabilirsiniz.'),
      findsOneWidget,
    );
    expect(await store.read(), isNull);
    expect(client.registrationMatches, isTrue);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'WrongPassword123!',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.pumpAndSettle();
    expect(
      tester
              .widget<TextFormField>(find.byType(TextFormField).at(0))
              .controller!
              .text ==
          email,
      isTrue,
      reason: 'Registered email must remain prefilled.',
    );
    expect(
      tester
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller!
              .text ==
          password,
      isTrue,
      reason: 'Correct password must reach the field controller.',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 45),
    );
    expect(
      find.byType(AppShell),
      findsOneWidget,
      reason:
          'Auth status: ${auth.status}; login matches: ${client.loginMatches}; email matches: ${client.emailMatches}; password matches: ${client.passwordMatches}; messages: ${tester.widgetList<AuthMessage>(find.byType(AuthMessage)).map((message) => message.message).join("; ")}',
    );
    expect(auth.user!.email, email);
    expect(auth.user!.roles, ['User']);
    expect(client.loginMatches, [false, true]);
    final initial = (await store.read())!;

    // A new service reads the native encrypted store, as on application launch.
    final restored = AuthService(
      ApiService(config, TokenStore(server: config.apiBaseUrl.toString())),
    );
    await restored.restoreSession();
    expect(restored.status, AuthStatus.signedIn);
    expect(restored.user!.id, auth.user!.id);
    restored.dispose();

    await Future.wait([api.refreshSession(), api.refreshSession()]);
    final rotated = (await store.read())!;
    expect(rotated.refreshToken == initial.refreshToken, isFalse);
    expect((await api.get('/api/users/me'))['email'], email);
    await expectLater(
      api.post('/api/auth/refresh', {'refreshToken': initial.refreshToken}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    // Exercise the actual 401 recovery path while keeping the valid refresh.
    await api.saveSession({
      'accessToken': 'invalid-jwt',
      'refreshToken': rotated.refreshToken,
      'expiresAt': rotated.expiresAt.toIso8601String(),
    });
    expect((await api.get('/api/users/me'))['email'], email);
    final current = (await store.read())!;
    expect(current.refreshToken == rotated.refreshToken, isFalse);

    await tester.tap(find.byTooltip('Profil ve Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Çıkış Yap'));
    await tester.tap(find.widgetWithText(FilledButton, 'Çıkış Yap'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(await store.read(), isNull);
    await expectLater(
      api.post('/api/auth/refresh', {'refreshToken': current.refreshToken}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}

// Compare credentials without printing their values in test diagnostics.
class AuthContractClient extends http.BaseClient {
  AuthContractClient(this.email, this.password);
  final String email;
  final String password;
  final http.Client _inner = http.Client();
  bool? registrationMatches;
  final List<bool> loginMatches = [];
  final List<bool> emailMatches = [];
  final List<bool> passwordMatches = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request &&
        ['/api/auth/register', '/api/auth/login'].contains(request.url.path)) {
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      final matches = json['email'] == email && json['password'] == password;
      if (request.url.path == '/api/auth/register') {
        registrationMatches = matches;
      } else {
        loginMatches.add(matches);
        emailMatches.add(json['email'] == email);
        passwordMatches.add(json['password'] == password);
      }
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
