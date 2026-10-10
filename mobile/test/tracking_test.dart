import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_entry_screen.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_models.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_service.dart';

import 'app_shell_test.dart' show openApp;
import 'auth_service_test.dart' show makeApi, jsonResponse, tokens, userJson;

const weightPath = '/api/users/me/weight-records';
const bodyPath = '/api/users/me/body-measurements';

Future<void> openTracking(WidgetTester tester) async {
  await tester.tap(find.byType(NavigationDestination).at(3));
  await tester.pumpAndSettle();
}

Future<void> saveForm(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Kaydet');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'list request uses Bearer and recovers 401 using existing refresh',
    () async {
      var refreshes = 0;
      var lists = 0;
      final api = makeApi((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          return jsonResponse(tokens('new'));
        }
        lists++;
        if (lists == 1) {
          expect(request.headers['Authorization'], 'Bearer access-old');
          return jsonResponse({}, 401);
        }
        expect(request.headers['Authorization'], 'Bearer access-new');
        return jsonResponse([
          {'id': 'w', 'weightKg': 82.4, 'recordedAt': '2026-01-01T08:00:00Z'},
        ]);
      });
      addTearDown(api.close);
      await api.saveSession(tokens('old'));
      final weights = await TrackingService(api).getWeightRecords();
      expect(weights.single.weightKg, 82.4);
      expect(refreshes, 1);
      expect(lists, 2);
    },
  );

  test(
    'tracking rejects malformed list and formats units without losing zeros',
    () async {
      final api = makeApi((_) async => jsonResponse({'invalid': true}));
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      await expectLater(
        TrackingService(api).getWeightRecords(),
        throwsA(isA<ApiException>()),
      );
      expect(trackingNumber(1000), '1000');
      expect(trackingNumber(80.5), '80,5');
      expect(trackingNumber(0), '0');
    },
  );

  testWidgets(
    'empty lists, real create/list contract and refreshed weight/body history',
    (tester) async {
      final weights = <Map<String, dynamic>>[];
      final bodies = <Map<String, dynamic>>[];
      final requests = <String>[];
      await openApp(
        tester,
        handler: (request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/users/me') {
            return jsonResponse(userJson);
          }
          expect(request.headers['Authorization'], 'Bearer access-saved');
          final records = request.url.path == weightPath ? weights : bodies;
          if (request.method == 'POST') {
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            expect(data.containsKey('userId'), isFalse);
            expect((data['recordedAt'] as String).endsWith('Z'), isTrue);
            records.insert(0, {'id': 'record-${records.length}', ...data});
            return jsonResponse(records.first, 201);
          }
          return jsonResponse(records);
        },
      );
      expect(requests, ['/api/users/me']);
      await openTracking(tester);
      expect(find.text('Henüz kilo kaydı yok'), findsOneWidget);
      await tester.ensureVisible(find.text('Henüz vücut ölçümü kaydı yok.'));
      expect(find.text('Henüz vücut ölçümü kaydı yok.'), findsOneWidget);
      final addWeight = find.widgetWithText(FilledButton, 'Kilo Ekle');
      await tester.ensureVisible(addWeight);
      await tester.tap(addWeight);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('weightKg')), '82,45');
      await saveForm(tester);
      expect(weights.single['weightKg'], 82.45);
      expect(find.text('82,45 kg'), findsNWidgets(2));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ölçüm Ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('waistCm')), '88.25');
      await saveForm(tester);
      expect(bodies.single['waistCm'], 88.25);
      expect(bodies.single['chestCm'], isNull);
      await tester.ensureVisible(find.text('Bel: 88,25 cm'));
      expect(find.text('Bel: 88,25 cm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed load has retry instead of false empty state', (
    tester,
  ) async {
    var failing = true;
    await openApp(
      tester,
      handler: (request) async {
        if (request.url.path == '/api/users/me') return jsonResponse(userJson);
        if (failing) return jsonResponse({}, 500);
        return jsonResponse([]);
      },
    );
    await openTracking(tester);
    expect(
      find.text('İşlem tamamlanamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Henüz kilo kaydı yok'), findsNothing);
    failing = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kilo kaydı yok'), findsOneWidget);
  });

  for (final invalid in ['', '0', '-1', '1000.01', '82.451', 'NaN', 'abc']) {
    testWidgets('invalid weight $invalid does not reach API', (tester) async {
      var posted = false;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/users/me') {
            return jsonResponse(userJson);
          }
          if (request.method == 'POST') posted = true;
          return jsonResponse([]);
        },
      );
      await openTracking(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Kilo Ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('weightKg')), invalid);
      await saveForm(tester);
      expect(find.byType(TrackingEntryScreen), findsOneWidget);
      expect(posted, isFalse);
    });
  }

  testWidgets(
    'measurement requires a value and checks percentage precision/range',
    (tester) async {
      var posted = false;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/users/me') {
            return jsonResponse(userJson);
          }
          if (request.method == 'POST') posted = true;
          return jsonResponse([]);
        },
      );
      await openTracking(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ölçüm Ekle'));
      await tester.pumpAndSettle();
      await saveForm(tester);
      expect(find.text('En az bir vücut ölçümü girin.'), findsOneWidget);
      for (final value in ['100.01', '-1', '20.123']) {
        final input = find.byKey(const ValueKey('bodyFatPercentage'));
        await tester.ensureVisible(input);
        await tester.enterText(input, value);
        await saveForm(tester);
        expect(
          find.text('0–100 arasında, en fazla iki ondalık basamak girin.'),
          findsOneWidget,
        );
      }
      expect(posted, isFalse);
    },
  );

  testWidgets(
    'save locks duplicate submission and preserves input after field error',
    (tester) async {
      final pending = Completer<http.Response>();
      var posts = 0;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/users/me') {
            return jsonResponse(userJson);
          }
          if (request.method == 'POST') {
            posts++;
            return pending.future;
          }
          return jsonResponse([]);
        },
      );
      await openTracking(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Kilo Ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('weightKg')), '82.4');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pump();
      expect(find.text('Kaydediliyor…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(
        jsonResponse({
          'errors': {
            'weightKg': ['Kilo değeri reddedildi.'],
          },
        }, 400),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kilo değeri reddedildi.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('weightKg')))
            .controller!
            .text,
        '82.4',
      );
      expect(posts, 1);
    },
  );

  testWidgets('expired session closes protected measurement form', (
    tester,
  ) async {
    final auth = await openApp(tester);
    await openTracking(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ölçüm Ekle'));
    await tester.pumpAndSettle();
    await auth.api.saveSession(tokens('expired', expired: true));
    await expectLater(auth.api.getList(bodyPath), throwsA(isA<ApiException>()));
    await tester.pumpAndSettle();
    expect(find.byType(TrackingEntryScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tracking and measurement form fit narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(tester);
      await openTracking(tester);
      final add = find.widgetWithText(OutlinedButton, 'Ölçüm Ekle');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('bodyFatPercentage')),
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Kaydet'));
      expect(tester.takeException(), isNull);
    },
  );
}
