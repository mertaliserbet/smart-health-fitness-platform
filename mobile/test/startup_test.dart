import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';

import 'auth_service_test.dart' show makeApi, tokens;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Android debug launch has central development configuration', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      AppConfig.fromEnvironment().apiBaseUrl.toString(),
      'http://10.0.2.2:5000/',
    );
  });

  testWidgets('no saved session shows Login without requesting backend', (
    tester,
  ) async {
    var requests = 0;
    final auth = AuthService(
      makeApi((_) async {
        requests++;
        throw http.ClientException('offline');
      }),
    );
    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(requests, 0);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'TestPassword123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Backend’in açık'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [
    MissingPluginException('unavailable'),
    PlatformException(code: 'storage_unavailable'),
  ]) {
    testWidgets('storage ${failure.runtimeType} displays recovery UI', (
      tester,
    ) async {
      final auth = storageAuth(() async => throw failure);
      await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Tekrar deneyin.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stalled storage exits loading after five seconds', (
    tester,
  ) async {
    final storageResponse = Completer<String?>();
    final auth = storageAuth(() => storageResponse.future);
    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(
      find.text('Cihazdaki oturum bilgileri okunamadı. Tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
    storageResponse.complete(null);
    await tester.pumpAndSettle();
    // A late native read cannot overwrite the already displayed error state.
    expect(auth.status, AuthStatus.retry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stalled me request shows recovery and preserves session', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final api = makeApi((_) => response.future);
    await api.saveSession(tokens('saved'));
    final auth = AuthService(api);
    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(
      find.text('İstek zaman aşımına uğradı. Tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(api.hasSession, isTrue);
    response.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(auth.status, AuthStatus.retry);
    expect(tester.takeException(), isNull);
  });
}

AuthService storageAuth(Future<String?> Function() read) {
  final config = AppConfig('https://api.example.test');
  return AuthService(
    ApiService(
      config,
      TokenStore(
        server: config.apiBaseUrl.toString(),
        storage: ReadStorage(read),
      ),
      client: MockClient((_) async => throw StateError('no HTTP expected')),
    ),
  );
}

class ReadStorage extends FlutterSecureStorage {
  ReadStorage(this.readValue);
  final Future<String?> Function() readValue;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => readValue();
}
