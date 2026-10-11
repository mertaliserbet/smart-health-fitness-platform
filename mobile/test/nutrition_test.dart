import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_entry_screen.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_models.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_screen.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_service.dart';

import 'app_shell_test.dart' show openApp;
import 'auth_service_test.dart' show makeApi, jsonResponse, tokens, userJson;
import 'tracking_test.dart' show openTracking, saveForm;

const path = NutritionService.path;
Map<String, dynamic> summary({int count = 0, bool goal = false}) => {
  'date': '2026-10-11',
  'recordCount': count,
  'consumedCalories': count * 650.25,
  'consumedProteinGrams': count * 48,
  'consumedCarbohydrateGrams': count * 72.5,
  'consumedFatGrams': count * 16,
  'goal': goal
      ? {
          'id': 'goal',
          'dailyCalories': 1000,
          'proteinGrams': 100,
          'carbohydrateGrams': 200,
          'fatGrams': 50,
          'waterMl': 2500,
          'isActive': true,
          'startDate': '2026-01-01',
          'endDate': null,
        }
      : null,
};
Map<String, dynamic> record() => {
  'id': 'record',
  'name': 'Tavuk ve pilav',
  'mealType': 'Lunch',
  'consumedAt': '2026-10-11T09:00:00Z',
  'calories': 650.25,
  'proteinGrams': 48,
  'carbohydrateGrams': 72.5,
  'fatGrams': 16,
};

Future<void> openNutrition(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  await openApp(
    tester,
    handler: (request) async {
      if (request.url.path == '/api/users/me') return jsonResponse(userJson);
      if (request.url.path == '/api/users/me/weight-records' ||
          request.url.path == '/api/users/me/body-measurements') {
        return jsonResponse([]);
      }
      return handler(request);
    },
  );
  await openTracking(tester);
  await tester.tap(find.widgetWithText(OutlinedButton, 'Beslenme'));
  await tester.pumpAndSettle();
}

Future<void> fillMeal(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('name')), 'Tavuk ve pilav');
  await tester.enterText(find.byKey(const ValueKey('calories')), '650,25');
  await tester.enterText(find.byKey(const ValueKey('proteinGrams')), '48');
  await tester.enterText(
    find.byKey(const ValueKey('carbohydrateGrams')),
    '72.5',
  );
  await tester.enterText(find.byKey(const ValueKey('fatGrams')), '16');
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'summary sends encoded local calendar midnight bounds and bearer token',
    () async {
      final day = DateTime(2026, 10, 11, 15);
      final api = makeApi((request) async {
        expect(request.url.path, '$path/daily-summary');
        expect(request.headers['Authorization'], 'Bearer access-saved');
        expect(request.url.queryParameters['date'], '2026-10-11');
        expect(
          DateTime.parse(request.url.queryParameters['from']!),
          DateTime(2026, 10, 11).toUtc(),
        );
        expect(
          DateTime.parse(request.url.queryParameters['to']!),
          DateTime(2026, 10, 12).toUtc(),
        );
        expect(
          request.url.queryParameters['from'],
          matches(RegExp(r'[+-]\d\d:\d\d$')),
        );
        return jsonResponse(summary(count: 1, goal: true));
      });
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      final result = await NutritionService(api).getDailySummary(day);
      expect(result.values['calories'], 650.25);
      expect(result.goal!.targets['dailyCalories'], 1000);
    },
  );

  test(
    'create sends manual source, UTC time and no user ownership field',
    () async {
      final consumed = DateTime(2026, 1, 1, 12);
      final api = makeApi((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer access-saved');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sourceType'], 'Manual');
        expect(body['foodRecognitionLogId'], isNull);
        expect(body['name'], 'Şehriyeli çorba');
        expect(body.containsKey('userId'), isFalse);
        expect(body['consumedAt'], consumed.toUtc().toIso8601String());
        return jsonResponse({'id': 'record', ...body}, 201);
      });
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      await NutritionService(api).createRecord(
        mealType: 'Lunch',
        name: ' Şehriyeli çorba ',
        values: {for (final key in nutrientLabels.keys) key: 0},
        consumedAt: consumed,
      );
    },
  );

  test('invalid response is a readable API error', () async {
    final api = makeApi(
      (_) async => jsonResponse([
        {'id': 'broken'},
      ]),
    );
    addTearDown(api.close);
    await api.saveSession(tokens('saved'));
    await expectLater(
      NutritionService(api).getRecords(),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => NutritionDailySummary.fromJson({
        ...summary(),
        'consumedCalories': -1,
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'empty state, create, reload totals, goal remaining and history',
    (tester) async {
      final records = <Map<String, dynamic>>[];
      await openNutrition(tester, (request) async {
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          records.add({'id': 'r', ...body});
          return jsonResponse(records.last, 201);
        }
        return jsonResponse(
          request.url.path.endsWith('daily-summary')
              ? summary(count: records.length, goal: true)
              : records,
        );
      });
      expect(
        find.text('Bu gün için henüz beslenme kaydı yok.'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Beslenme Kaydı Ekle'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Beslenme Kaydı Ekle'),
      );
      await tester.pumpAndSettle();
      await fillMeal(tester);
      await saveForm(tester);
      expect(find.byType(NutritionEntryScreen), findsNothing);
      expect(find.text('650,25 / 1000'), findsOneWidget);
      expect(find.text('Kalan: 349,75'), findsOneWidget);
      await tester.ensureVisible(find.text('Tavuk ve pilav'));
      expect(find.text('Tavuk ve pilav'), findsOneWidget);
      expect(records.single['carbohydrateGrams'], 72.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no assigned goal and exceeded goal display without fabricated target',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NutritionSummaryCard(
              summary: NutritionDailySummary.fromJson(summary(count: 1)),
            ),
          ),
        ),
      );
      expect(find.text('650,25'), findsOneWidget);
      expect(
        find.textContaining('geçerli aktif beslenme hedefin yok'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NutritionSummaryCard(
              summary: NutritionDailySummary.fromJson(
                summary(count: 2, goal: true),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Hedefin üzerinde: 300,5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('summary and history error offers retry', (tester) async {
    var fail = true;
    await openNutrition(
      tester,
      (request) async => fail
          ? jsonResponse({}, 503)
          : jsonResponse(
              request.url.path.endsWith('daily-summary') ? summary() : [],
            ),
    );
    expect(
      find.text('İşlem tamamlanamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Bu gün için henüz beslenme kaydı yok.'), findsNothing);
    fail = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Bu gün için henüz beslenme kaydı yok.'), findsOneWidget);
  });

  testWidgets(
    'form requires name and all values, rejects negatives and precision; permits zero',
    (tester) async {
      var posts = 0;
      final api = makeApi((request) async {
        posts++;
        return jsonResponse({});
      });
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      await tester.pumpWidget(
        MaterialApp(
          home: NutritionEntryScreen(
            service: NutritionService(api),
            day: DateTime.now(),
          ),
        ),
      );
      await saveForm(tester);
      expect(find.text('Öğün / besin adı zorunludur.'), findsOneWidget);
      expect(posts, 0);
      await fillMeal(tester);
      for (final invalid in ['-1', '12.345', 'abc', '10000000000']) {
        await tester.enterText(find.byKey(const ValueKey('calories')), invalid);
        await saveForm(tester);
        expect(posts, 0);
        expect(find.textContaining('en fazla iki ondalık'), findsOneWidget);
      }
      for (final key in nutrientLabels.keys) {
        await tester.enterText(find.byKey(ValueKey(key)), '0');
      }
      await saveForm(tester);
      expect(posts, 1);
    },
  );

  testWidgets('save error preserves input and maps server field errors', (
    tester,
  ) async {
    final api = makeApi(
      (_) async => jsonResponse({
        'errors': {
          'calories': ['Kalori değeri geçersiz.'],
        },
      }, 400),
    );
    addTearDown(api.close);
    await api.saveSession(tokens('saved'));
    await tester.pumpWidget(
      MaterialApp(
        home: NutritionEntryScreen(
          service: NutritionService(api),
          day: DateTime.now(),
        ),
      ),
    );
    await fillMeal(tester);
    await saveForm(tester);
    expect(find.byType(NutritionEntryScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('calories')))
          .controller!
          .text,
      '650,25',
    );
    expect(find.text('Kalori değeri geçersiz.'), findsOneWidget);
  });

  testWidgets('loading is visible and repeated save cannot submit twice', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var posts = 0;
    final api = makeApi((_) {
      posts++;
      return pending.future;
    });
    addTearDown(api.close);
    await api.saveSession(tokens('saved'));
    await tester.pumpWidget(
      MaterialApp(
        home: NutritionEntryScreen(
          service: NutritionService(api),
          day: DateTime.now(),
        ),
      ),
    );
    await fillMeal(tester);
    final button = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Kaydediliyor…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Kaydediliyor…'),
          )
          .onPressed,
      isNull,
    );
    expect(posts, 1);
    pending.complete(jsonResponse({}, 503));
    await tester.pumpAndSettle();
    expect(find.text('Kaydet'), findsOneWidget);
  });

  testWidgets('expired session removes nutrition form and returns to login', (
    tester,
  ) async {
    var expired = false;
    await openNutrition(tester, (request) async {
      if (expired || request.url.path == '/api/auth/refresh') {
        return jsonResponse({}, 401);
      }
      return jsonResponse(
        request.url.path.endsWith('daily-summary') ? summary() : [],
      );
    });
    await tester.tap(find.widgetWithText(FilledButton, 'Beslenme Kaydı Ekle'));
    await tester.pumpAndSettle();
    await fillMeal(tester);
    expired = true;
    await saveForm(tester);
    expect(find.byType(NutritionEntryScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
  });

  testWidgets(
    'narrow screen and larger text remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = makeApi(
        (request) async => jsonResponse(
          request.url.path.endsWith('daily-summary')
              ? summary(count: 2, goal: true)
              : [record()],
        ),
      );
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: NutritionScreen(service: NutritionService(api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1300,5 / 1000'), findsOneWidget);
      await tester.ensureVisible(find.text('Beslenme Kaydı Ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beslenme Kaydı Ekle'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kaydet'));
      expect(tester.takeException(), isNull);
    },
  );
}
