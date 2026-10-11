import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_health_fitness_mobile/features/running/running_models.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_progress.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_widgets.dart';

import 'app_shell_test.dart' show openApp, emptyNutritionSummary;
import 'auth_service_test.dart' show jsonResponse, userJson;
import 'tracking_test.dart' show openTracking;

DateTime recordTime(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo);
}

Map<String, dynamic> run(int daysAgo, double meters, int seconds) => {
  'id': 'run-$daysAgo',
  'startedAt': recordTime(daysAgo).toUtc().toIso8601String(),
  'endedAt': recordTime(
    daysAgo,
  ).add(Duration(seconds: seconds)).toUtc().toIso8601String(),
  'durationSeconds': seconds,
  'distanceMeters': meters,
  'averagePaceSecondsPerKm': null,
  'averageSpeedKmh': meters * 3.6 / seconds,
};

http.Response progressResponse(http.Request request) {
  switch (request.url.path) {
    case '/api/users/me':
      return jsonResponse(userJson);
    case '/api/users/me/weight-records':
      return jsonResponse([
        for (final day in [0, 6, 29, 45])
          {
            'id': 'w-$day',
            'weightKg': 80 + day / 10,
            'recordedAt': recordTime(day).toUtc().toIso8601String(),
          },
      ]);
    case '/api/users/me/body-measurements':
      return jsonResponse([
        for (final day in [0, 6, 29, 45])
          {
            'id': 'b-$day',
            'waistCm': 85 + day / 10,
            'chestCm': null,
            'bodyFatPercentage': 20 + day / 10,
            'recordedAt': recordTime(day).toUtc().toIso8601String(),
          },
      ]);
    case '/api/users/me/running-activities':
      return jsonResponse([
        run(0, 1000, 600),
        run(6, 2000, 1200),
        run(29, 3000, 1800),
        run(45, 4000, 2400),
      ]);
    case '/api/users/me/nutrition-records/daily-summary':
      return jsonResponse({
        ...emptyNutritionSummary(),
        'recordCount': 1,
        'consumedCalories': 1100,
        'consumedProteinGrams': 68,
        'consumedCarbohydrateGrams': 133,
        'consumedFatGrams': 28,
        'goal': {
          'id': 'g',
          'dailyCalories': 2000,
          'proteinGrams': 100,
          'carbohydrateGrams': 250,
          'fatGrams': 70,
          'waterMl': 2500,
          'isActive': true,
          'startDate': '2020-01-01',
          'endDate': null,
        },
      });
    default:
      throw StateError('Unexpected request ${request.url}');
  }
}

Future<void> selectPeriod(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    '7/30 day filters use inclusive calendar boundaries and exclude future days',
    () {
      final now = DateTime(2026, 10, 11, 13);
      expect(TrackingPeriod.week.contains(DateTime(2026, 10, 5), now), isTrue);
      expect(
        TrackingPeriod.week.contains(DateTime(2026, 10, 4, 23, 59), now),
        isFalse,
      );
      expect(
        TrackingPeriod.week.contains(DateTime(2026, 10, 11, 23, 59), now),
        isTrue,
      );
      expect(TrackingPeriod.all.contains(DateTime(2026, 10, 12), now), isFalse);
      expect(TrackingPeriod.month.contains(DateTime(2026, 9, 12), now), isTrue);
      expect(
        TrackingPeriod.month.contains(DateTime(2026, 9, 11, 23, 59), now),
        isFalse,
      );
      expect(TrackingPeriod.all.contains(DateTime(1990), now), isTrue);
    },
  );

  test(
    'series sorts actual timestamps, chooses API-first duplicate and does not fill gaps',
    () {
      final series = progressSeries([
        (at: DateTime(2026, 10, 11), value: 80.0),
        (at: DateTime(2026, 10, 11), value: 81.0),
        (at: DateTime(2026, 10, 1), value: 82.0),
      ]);
      expect(series.length, 2);
      expect(series.map((p) => p.value), [82, 80]);
      expect(series.last.at.difference(series.first.at).inDays, 10);
    },
  );

  test(
    'running totals sum stored metres and active duration, not wall time',
    () {
      final totals = runningTotals([
        RunningActivity.fromJson(run(0, 0, 15)),
        RunningActivity.fromJson(run(2, 1234.56, 65)),
      ]);
      expect(totals, (count: 2, distanceMeters: 1234.56, durationSeconds: 80));
      expect(runningTotals([]), (
        count: 0,
        distanceMeters: 0.0,
        durationSeconds: 0,
      ));
    },
  );

  testWidgets(
    'period controls filter charts/history/run totals without extra HTTP or fake missing values',
    (tester) async {
      var calls = 0;
      await openApp(
        tester,
        handler: (request) async {
          calls++;
          return progressResponse(request);
        },
      );
      await openTracking(tester);
      expect(calls, 5);
      expect(find.text('30 gün • 3 kayıt'), findsOneWidget);
      expect(find.text('Değişim: -2,9 kg'), findsOneWidget);
      expect(find.text('Toplam mesafe: 6 km'), findsOneWidget);
      expect(find.text('Toplam aktif süre: 1:00:00'), findsOneWidget);
      expect(find.text('1100 / 2000'), findsOneWidget);
      expect(find.text('68 / 100'), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-plot')), findsNWidgets(2));
      await selectPeriod(tester, '7 gün');
      expect(find.text('7 gün • 2 kayıt'), findsOneWidget);
      expect(find.text('Değişim: -0,6 kg'), findsOneWidget);
      expect(find.text('Toplam mesafe: 3 km'), findsOneWidget);
      expect(find.text('Toplam aktif süre: 0:30:00'), findsOneWidget);
      await selectPeriod(tester, 'Tüm zamanlar');
      expect(find.text('Tüm zamanlar • 4 kayıt'), findsOneWidget);
      expect(find.text('Toplam mesafe: 10 km'), findsOneWidget);
      expect(calls, 5);
      final dropdown = find.byKey(const ValueKey('progress-measurement'));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vücut yağ oranı').last);
      await tester.pumpAndSettle();
      expect(find.text('Değişim: -4,5 yüzde puan'), findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Göğüs').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Bu dönemde seçili ölçüm için kayıt yok.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one unavailable API keeps other data; retry preserves stale data and loading',
    (tester) async {
      final pending = Completer<http.Response>();
      var weightCalls = 0;
      await openApp(
        tester,
        handler: (request) async {
          if (request.url.path.endsWith('running-activities')) {
            return jsonResponse({}, 503);
          }
          if (request.url.path.endsWith('weight-records') &&
              ++weightCalls == 2) {
            return pending.future;
          }
          return progressResponse(request);
        },
      );
      await openTracking(tester);
      expect(find.text('80 kg'), findsNWidgets(2));
      expect(find.text('1100 / 2000'), findsOneWidget);
      expect(find.text('Henüz koşu kaydı yok.'), findsNothing);
      // Refresh all sources while one request is pending, without hiding last good data.
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('Kayıtlar yükleniyor…'), findsWidgets);
      expect(find.text('80 kg'), findsNWidgets(2));
      pending.complete(jsonResponse({}, 500));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('Son yüklenen kayıtlar gösteriliyor.'), findsOneWidget);
      expect(find.text('80 kg'), findsNWidgets(2));
    },
  );

  testWidgets(
    'chart handles single point and unchanged values; tap displays real oldest value',
    (tester) async {
      Future<void> show(List<ProgressPoint> points) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressChart(points: points, unit: 'kg', empty: 'Veri yok'),
          ),
        ),
      );
      await show([(at: DateTime(2026, 1, 1), value: 80)]);
      expect(find.byKey(const ValueKey('progress-plot')), findsNothing);
      expect(
        find.text('Grafik için farklı zamanlarda en az iki kayıt gerekli.'),
        findsOneWidget,
      );
      await show([
        (at: DateTime(2026, 1, 1), value: 80),
        (at: DateTime(2026, 1, 3), value: 80),
      ]);
      expect(find.text('Değişim: 0 kg'), findsOneWidget);
      final chart = find.byKey(const ValueKey('progress-plot'));
      await tester.tapAt(tester.getTopLeft(chart) + const Offset(8, 70));
      await tester.pump();
      expect(find.text('01.01.2026 00:00 • 80 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'populated dashboard and charts fit narrow screen and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(
        tester,
        handler: (request) async => progressResponse(request),
      );
      await openTracking(tester);
      for (final title in [
        'Kilo gelişimi',
        'Vücut ölçümü gelişimi',
        'Günlük kalori ve makrolar',
        'Koşu özeti',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Toplam aktif süre: 1:00:00'), findsOneWidget);
    },
  );
}
