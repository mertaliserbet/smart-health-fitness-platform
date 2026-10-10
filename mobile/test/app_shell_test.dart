import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/navigation/app_shell.dart';
import 'package:smart_health_fitness_mobile/features/profile/profile_screen.dart';

import 'auth_service_test.dart' show makeApi, jsonResponse, tokens, userJson;

const labels = ['Ana Sayfa', 'Planım', 'AI', 'Takip', 'Rehberim'];

Future<AuthService> openApp(
  WidgetTester tester, {
  bool savedSession = true,
  Future<http.Response> Function(http.Request)? handler,
}) async {
  final api = makeApi(
    handler ??
        (request) async {
          return switch (request.url.path) {
            '/api/users/me' => jsonResponse(userJson),
            '/api/auth/login' => jsonResponse({
              ...tokens('login'),
              'user': userJson,
            }),
            '/api/auth/logout' => http.Response('', 204),
            '/api/auth/refresh' => jsonResponse({
              'title': 'Invalid or expired refresh token',
            }, 401),
            _ => throw StateError('Unexpected request: ${request.url.path}'),
          };
        },
  );
  if (savedSession) await api.saveSession(tokens('saved'));
  final auth = AuthService(api);
  await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('login opens the five-tab dark application shell', (
    tester,
  ) async {
    await openApp(tester, savedSession: false);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'mert@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(
      bar.destinations.cast<NavigationDestination>().map((d) => d.label),
      labels,
    );
    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFF4D8DFF));
  });

  testWidgets(
    'all tabs work without module API calls; profile is outside the menu',
    (tester) async {
      final requests = <String>[];
      await openApp(
        tester,
        handler: (request) async {
          requests.add(request.url.path);
          return jsonResponse(userJson);
        },
      );
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
        expect(find.widgetWithText(AppBar, labels[index]), findsOneWidget);
        expect(
          find.byTooltip('Profil ve Ayarlar'),
          index == 0 ? findsOneWidget : findsNothing,
        );
      }
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text(userJson['email'] as String), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(requests, ['/api/users/me']);
    },
  );

  testWidgets(
    'profile logout shows loading and returns to Login, with no protected back route',
    (tester) async {
      final response = Completer<http.Response>();
      var logoutRequests = 0;
      final auth = await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/auth/logout') {
            logoutRequests++;
            return response.future;
          }
          return jsonResponse(userJson);
        },
      );
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış Yap'));
      await tester.pump();
      expect(find.text('Çıkış yapılıyor…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(logoutRequests, 1);
      response.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(await auth.api.tokenStore.read(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired refresh removes profile and a new login resets the selected tab',
    (tester) async {
      final auth = await openApp(tester);
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await tester.pumpAndSettle();
      await auth.api.saveSession(tokens('expired', expired: true));
      await expectLater(
        auth.api.get('/api/users/me'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'mert@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 480),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('shell and profile fit $size with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(
        tester,
        handler: (_) async => jsonResponse({
          ...userJson,
          'firstName': 'Mert Ali Uzun Bir Isim',
          'lastName': 'Uzun Bir Soyad',
          'email': 'very.long.account.name.for.layout.check@example.test',
        }),
      );
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Çıkış Yap'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
