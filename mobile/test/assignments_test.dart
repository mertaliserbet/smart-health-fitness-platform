import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/features/assignments/assignment_service.dart';
import 'package:smart_health_fitness_mobile/features/plans/my_plan_screen.dart';

import 'app_shell_test.dart' show openApp;
import 'auth_service_test.dart' show makeApi, jsonResponse, tokens, userJson;

// Contract fixtures live only in tests; the application never supplies demo data.
final planJson = {
  'id': 'plan-id',
  'name': 'Atanmış kuvvet programı',
  'isActive': true,
  'startDate': '2026-01-01',
  'endDate': null,
};
final detailJson = {
  ...planJson,
  'description': 'Koç açıklaması',
  'days': [
    {
      'name': 'Kuvvet',
      'dayNumber': 1,
      'weekday': 'Monday',
      'exercises': [
        {
          'exerciseName': 'Squat',
          'order': 1,
          'sets': 3,
          'reps': 10,
          'restSeconds': 90,
          'weightKg': null,
          'notes': 'Kontrollü hareket',
        },
      ],
    },
  ],
};
final nutritionJson = {
  'id': 'goal-id',
  'isActive': true,
  'startDate': '2026-01-01',
  'endDate': null,
  'dailyCalories': 2300,
  'proteinGrams': 150,
  'carbohydrateGrams': 260,
  'fatGrams': 70,
  'waterMl': 2500,
};
final advisorsJson = [
  for (final type in ['Trainer', 'Trainer', 'Dietitian'])
    {
      'userAdvisorId': 'relationship-$type',
      'advisorId': 'advisor-$type',
      'advisorType': type,
      'firstName': type == 'Trainer' ? 'Çağrı' : 'İrem',
      'lastName': 'Şerbet',
      'title': type == 'Trainer' ? 'Antrenör' : null,
      'specialization': 'Spor',
      'startDate': '2026-01-01',
      'status': 'Active',
    },
];
final taskJson = {
  'id': 'task-id',
  'advisorId': 'advisor-id',
  'title': 'Esneme yap',
  'description': 'On dakika',
  'dueDate': '2026-12-01',
  'status': 'Pending',
};
final noteJson = {
  'id': 'note-id',
  'advisorId': 'advisor-id',
  'title': 'Koç notu',
  'content': 'Hareketleri kontrollü yap.',
  'createdAt': '2026-10-01T12:00:00Z',
};

Future<http.Response> fixture(http.Request request) async =>
    switch (request.url.path) {
      '/api/users/me' => jsonResponse(userJson),
      '/api/users/me/workout-plans' => jsonResponse([planJson]),
      '/api/workout-plans/plan-id' => jsonResponse(detailJson),
      '/api/users/me/nutrition-goals/active' => jsonResponse(nutritionJson),
      '/api/users/me/tasks' => jsonResponse([taskJson]),
      '/api/users/me/advisor-notes' => jsonResponse([noteJson]),
      '/api/users/me/advisors' => jsonResponse(advisorsJson),
      _ => throw StateError('Unexpected route ${request.url.path}'),
    };

Future<void> selectTab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NavigationDestination).at(index));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'all assignment calls use Bearer and documented routes; target uses local date',
    () async {
      final requests = <http.Request>[];
      final api = makeApi((request) async {
        requests.add(request);
        return fixture(request);
      });
      addTearDown(api.close);
      await api.saveSession(tokens('assignments'));
      final service = AssignmentService(api);
      expect((await service.getWorkoutPlans()).single.name, planJson['name']);
      expect(
        (await service.getWorkoutPlan('plan-id')).days.single.weekday,
        'Monday',
      );
      expect(
        (await service.getActiveNutritionGoal())!.targets['dailyCalories'],
        2300,
      );
      expect((await service.getAdvisors()).length, 3);
      expect((await service.getTasks()).single.status, 'Pending');
      expect((await service.getNotes()).single.content, noteJson['content']);
      expect(
        requests.every(
          (r) => r.headers['Authorization'] == 'Bearer access-assignments',
        ),
        isTrue,
      );
      expect(
        requests[2].url.queryParameters['date'],
        DateTime.now().toIso8601String().substring(0, 10),
      );
    },
  );

  test(
    'only domain-coded nutrition 404 means no target; missing route is an error',
    () async {
      var coded = false;
      final api = makeApi(
        (_) async => coded
            ? jsonResponse({'code': 'NutritionGoalNotFound'}, 404)
            : http.Response('', 404),
      );
      addTearDown(api.close);
      await api.saveSession(tokens('target'));
      final service = AssignmentService(api);
      await expectLater(
        service.getActiveNutritionGoal(),
        throwsA(isA<ApiException>()),
      );
      coded = true;
      expect(await service.getActiveNutritionGoal(), isNull);
    },
  );

  test('inactive or out-of-period nutrition target is not shown', () async {
    var extra = <String, Object>{'isActive': false};
    final api = makeApi(
      (_) async => jsonResponse({...nutritionJson, ...extra}),
    );
    addTearDown(api.close);
    await api.saveSession(tokens('invalid-target'));
    final service = AssignmentService(api);
    for (final change in [
      {'isActive': false},
      {'startDate': '2099-01-01'},
      {'endDate': '2026-01-02'},
    ]) {
      extra = change;
      await expectLater(
        service.getActiveNutritionGoal(),
        throwsA(isA<ApiException>()),
      );
    }
  });

  testWidgets(
    'plan loads lazily; detail, nutrition and tasks display HTTP response fields',
    (tester) async {
      final requests = <String>[];
      await openApp(
        tester,
        handler: (request) async {
          requests.add(request.url.path);
          return fixture(request);
        },
      );
      expect(requests, ['/api/users/me']);
      await selectTab(tester, 1);
      expect(find.text('Atanmış kuvvet programı'), findsOneWidget);
      expect(requests, ['/api/users/me', '/api/users/me/workout-plans']);
      await tester.tap(find.text('Programı Gör'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutPlanDetailScreen), findsOneWidget);
      expect(find.text('Pazartesi • Kuvvet'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Set: 3'), findsOneWidget);
      expect(find.text('Dinlenme: 90 sn'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Beslenme'));
      await tester.pumpAndSettle();
      expect(find.text('Kalori hedefi (kcal): 2300'), findsOneWidget);
      expect(find.text('Su hedefi (ml): 2500'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Görevler'));
      await tester.pumpAndSettle();
      expect(find.text('Esneme yap'), findsOneWidget);
      expect(find.text('Bekliyor'), findsOneWidget);
      await tester.ensureVisible(find.text('Koç notu'));
      expect(find.text('Hareketleri kontrollü yap.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advisors are grouped by role and multiple coaches are supported',
    (tester) async {
      await openApp(tester, handler: fixture);
      await selectTab(tester, 4);
      expect(find.text('Çağrı Şerbet'), findsNWidgets(2));
      await tester.ensureVisible(find.text('İrem Şerbet'));
      expect(find.text('Diyetisyen • Dietitian'), findsOneWidget);
      expect(find.text('Uzmanlık: Spor'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful empty lists and coded no-goal show empty states', (
    tester,
  ) async {
    await openApp(
      tester,
      handler: (request) async {
        if (request.url.path == '/api/users/me') return jsonResponse(userJson);
        if (request.url.path.endsWith('/active')) {
          return jsonResponse({'code': 'NutritionGoalNotFound'}, 404);
        }
        return jsonResponse([]);
      },
    );
    await selectTab(tester, 1);
    expect(find.text('Henüz antrenman programı atanmadı.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Beslenme'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün için aktif beslenme hedefi yok.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Görevler'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz görev atanmadı.'), findsOneWidget);
    await tester.ensureVisible(find.text('Henüz danışman notu yok.'));
    await selectTab(tester, 4);
    expect(find.text('Henüz koç atanmadı.'), findsOneWidget);
    expect(find.text('Henüz diyetisyen atanmadı.'), findsOneWidget);
  });

  testWidgets(
    'missing backend route shows service error, never fake empty data; retry recovers',
    (tester) async {
      var available = false;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/users/me') {
            return jsonResponse(userJson);
          }
          return available ? fixture(request) : http.Response('', 404);
        },
      );
      await selectTab(tester, 1);
      expect(find.textContaining('servisi henüz hazır değil'), findsOneWidget);
      expect(find.text('Henüz antrenman programı atanmadı.'), findsNothing);
      available = true;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Atanmış kuvvet programı'), findsOneWidget);
    },
  );

  testWidgets(
    'note failure does not hide tasks and failed refresh labels retained data',
    (tester) async {
      var failTasks = false;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path.endsWith('/advisor-notes') ||
              (failTasks && request.url.path.endsWith('/tasks'))) {
            return http.Response('', 503);
          }
          return fixture(request);
        },
      );
      await selectTab(tester, 1);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Görevler'));
      await tester.pumpAndSettle();
      expect(find.text('Esneme yap'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('İşlem tamamlanamadı'));
      expect(find.text('Henüz danışman notu yok.'), findsNothing);
      failTasks = true;
      await tester.ensureVisible(find.text('Yenile'));
      await tester.tap(find.text('Yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Son yüklenen veriler gösteriliyor.'), findsOneWidget);
      expect(find.text('Esneme yap'), findsOneWidget);
    },
  );

  testWidgets('loading and malformed dates stay visible without crashing', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await openApp(
      tester,
      handler: (request) async => request.url.path == '/api/users/me'
          ? jsonResponse(userJson)
          : response.future,
    );
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pump();
    expect(find.text('Yükleniyor…'), findsOneWidget);
    response.complete(
      jsonResponse([
        {...planJson, 'startDate': 'bad-date'},
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Veriler okunamadı. Tekrar deneyin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expired auth removes protected plan detail and returns to login',
    (tester) async {
      final auth = await openApp(
        tester,
        handler: (request) async {
          if (request.url.path == '/api/auth/refresh') {
            return http.Response('', 401);
          }
          return fixture(request);
        },
      );
      await selectTab(tester, 1);
      await tester.tap(find.text('Programı Gör'));
      await tester.pumpAndSettle();
      await auth.api.saveSession(tokens('expired', expired: true));
      await tester.tap(find.text('Yenile'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutPlanDetailScreen), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 480),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('plan and advisor content fits $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(tester, handler: fixture);
      await selectTab(tester, 1);
      for (final label in ['Beslenme', 'Görevler', 'Antrenman']) {
        await tester.tap(find.widgetWithText(ChoiceChip, label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await selectTab(tester, 4);
      await tester.ensureVisible(find.text('İrem Şerbet'));
      expect(tester.takeException(), isNull);
    });
  }
}
