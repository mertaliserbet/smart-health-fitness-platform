import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:smart_health_fitness_mobile/core/app_theme.dart';
import 'package:smart_health_fitness_mobile/features/health/health_data_screen.dart';
import 'package:smart_health_fitness_mobile/features/health/health_models.dart';
import 'package:smart_health_fitness_mobile/features/health/health_service.dart';

import 'app_shell_test.dart' show openApp;

final day = DateTime(2026, 10, 13, 12);
HealthDataPoint sample(
  HealthDataType type,
  num value,
  DateTime time, {
  String source = 'Test kaynağı',
  String id = 'sample',
}) => HealthDataPoint(
  uuid: id,
  value: NumericHealthValue(numericValue: value),
  type: type,
  unit: type == HealthDataType.STEPS
      ? HealthDataUnit.COUNT
      : type == HealthDataType.HEART_RATE
      ? HealthDataUnit.BEATS_PER_MINUTE
      : HealthDataUnit.KILOCALORIE,
  dateFrom: time.subtract(const Duration(minutes: 1)),
  dateTo: time,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'test',
  sourceId: 'test',
  sourceName: source,
);

class TestHealth extends Health {
  HealthConnectSdkStatus? status = HealthConnectSdkStatus.sdkAvailable;
  final granted = <HealthDataType>{};
  final unavailable = <HealthDataType>{};
  final failed = <HealthDataType>{};
  final data = <HealthDataType, List<HealthDataPoint>>{};
  final queries = <({HealthDataType type, DateTime from, DateTime to})>[];
  List<HealthDataType>? requested;
  List<HealthDataAccess>? requestedAccess;
  bool allowRequest = true, failConfigure = false;
  int configured = 0, totalReads = 0, statisticsReads = 0;
  int? steps = 5000;
  List<HealthDataPoint> calorieTotals = [];
  Completer<void>? permissionPrompt;
  HealthDataType? revokeDuringRead;
  @override
  Future<void> configure() async {
    configured++;
    if (failConfigure) throw PlatformException(code: 'test');
  }

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async => status;
  @override
  bool isDataTypeAvailable(HealthDataType type) => !unavailable.contains(type);
  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    expect(permissions, everyElement(HealthDataAccess.READ));
    return granted.containsAll(types);
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    requested = types;
    requestedAccess = permissions;
    await permissionPrompt?.future;
    if (allowRequest) granted.addAll(types);
    return allowRequest;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    queries.add((type: types.single, from: startTime, to: endTime));
    if (failed.contains(types.single)) {
      throw PlatformException(code: 'read');
    }
    if (types.single == revokeDuringRead) granted.remove(types.single);
    return data[types.single] ?? [];
  }

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async {
    totalReads++;
    return steps;
  }

  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    statisticsReads++;
    expect(interval, greaterThan(0));
    return calorieTotals;
  }
}

Future<void> showHealth(
  WidgetTester tester,
  TestHealth sdk, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: HealthDataScreen(
        service: HealthService(health: sdk, platform: platform),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), (
          call,
        ) async {
          expect(call.method, 'checkIfHealthDataAvailable');
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), null),
  );

  test(
    'unsupported platform/provider and installation state never ask permission or read data',
    () async {
      final sdk = TestHealth();
      final unsupported = await HealthService(
        health: sdk,
        platform: TargetPlatform.windows,
      ).read(HealthMetric.values.toSet());
      expect(unsupported.availability, HealthAvailability.unsupported);
      expect(sdk.configured, 0);
      sdk.status = HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
      final missing = await HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      ).read(HealthMetric.values.toSet(), requestPermissions: true);
      expect(missing.availability, HealthAvailability.installRequired);
      expect(sdk.requested, isNull);
      expect(sdk.queries, isEmpty);
      sdk.status = null;
      await expectLater(
        HealthService(
          health: sdk,
          platform: TargetPlatform.android,
        ).read({HealthMetric.steps}),
        throwsA(isA<HealthReadException>()),
      );
    },
  );

  test(
    'initial reads do not request permission and missing grants never become zero data',
    () async {
      final sdk = TestHealth();
      final result = await HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      ).read(HealthMetric.values.toSet());
      expect(
        result.readings.values.map((r) => r.status),
        everyElement(HealthReadStatus.permissionRequired),
      );
      expect(result.readings.values.map((r) => r.value), everyElement(isNull));
      expect(sdk.requested, isNull);
      expect(sdk.queries, isEmpty);
    },
  );

  test(
    'request contains selected, missing READ permissions only; partial denial is preserved',
    () async {
      final sdk = TestHealth()..allowRequest = false;
      sdk.granted.add(HealthDataType.STEPS);
      final result =
          await HealthService(
            health: sdk,
            platform: TargetPlatform.android,
          ).read({
            HealthMetric.steps,
            HealthMetric.heartRate,
          }, requestPermissions: true);
      expect(sdk.requested, [HealthDataType.HEART_RATE]);
      expect(sdk.requestedAccess, [HealthDataAccess.READ]);
      expect(
        result.readings[HealthMetric.steps]!.status,
        HealthReadStatus.noData,
      );
      expect(
        result.readings[HealthMetric.heartRate]!.status,
        HealthReadStatus.permissionRequired,
      );
      expect(result.readings.containsKey(HealthMetric.activeCalories), isFalse);
    },
  );

  test(
    'totals use native aggregation, latest heart sample and actual timestamps/sources',
    () async {
      final sdk = TestHealth();
      sdk.granted.addAll([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
      ]);
      sdk.data[HealthDataType.STEPS] = [
        sample(HealthDataType.STEPS, 4000, day),
        sample(HealthDataType.STEPS, 4000, day, id: 'watch', source: 'Saat'),
      ];
      sdk.data[HealthDataType.ACTIVE_ENERGY_BURNED] = [
        sample(HealthDataType.ACTIVE_ENERGY_BURNED, 100, day),
      ];
      sdk.calorieTotals = [
        sample(HealthDataType.ACTIVE_ENERGY_BURNED, 150.5, day),
      ];
      sdk.data[HealthDataType.HEART_RATE] = [
        sample(
          HealthDataType.HEART_RATE,
          80,
          day.subtract(const Duration(days: 2)),
          id: 'old',
        ),
        sample(HealthDataType.HEART_RATE, 75, day),
      ];
      final result = await HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      ).read(HealthMetric.values.toSet(), now: day);
      expect(
        result.readings[HealthMetric.steps]!.value,
        5000,
      ); // Not 8000 from overlapping raw sources.
      expect(
        result.readings[HealthMetric.steps]!.sources,
        containsAll(['Test kaynağı', 'Saat']),
      );
      expect(result.readings[HealthMetric.activeCalories]!.value, 150.5);
      expect(result.readings[HealthMetric.heartRate]!.value, 75);
      expect(result.readings[HealthMetric.heartRate]!.recordedAt, day);
      expect(sdk.queries.first.from, DateTime(2026, 10, 13));
      expect(sdk.queries.last.from, DateTime(2026, 10, 7));
      expect(sdk.totalReads, 1);
      expect(sdk.statisticsReads, 1);
    },
  );

  test(
    'no samples stay empty; genuine zero samples are allowed; failed types do not hide others',
    () async {
      final sdk = TestHealth();
      sdk.granted.addAll([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
      ]);
      sdk.failed.add(HealthDataType.HEART_RATE);
      final service = HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      );
      var result = await service.read(HealthMetric.values.toSet(), now: day);
      expect(result.readings[HealthMetric.steps]!.value, isNull);
      expect(
        result.readings[HealthMetric.activeCalories]!.status,
        HealthReadStatus.noData,
      );
      expect(
        result.readings[HealthMetric.heartRate]!.status,
        HealthReadStatus.failed,
      );
      expect(sdk.totalReads, 0);
      sdk.steps = 0;
      sdk.data[HealthDataType.STEPS] = [sample(HealthDataType.STEPS, 0, day)];
      result = await service.read({HealthMetric.steps}, now: day);
      expect(
        result.readings[HealthMetric.steps]!.status,
        HealthReadStatus.data,
      );
      expect(result.readings[HealthMetric.steps]!.value, 0);
    },
  );

  test(
    'unsupported kind is skipped; missing aggregate remains error rather than invented zero',
    () async {
      final sdk = TestHealth();
      sdk.unavailable.add(HealthDataType.HEART_RATE);
      sdk.granted.add(HealthDataType.ACTIVE_ENERGY_BURNED);
      sdk.data[HealthDataType.ACTIVE_ENERGY_BURNED] = [
        sample(HealthDataType.ACTIVE_ENERGY_BURNED, 100, day),
      ];
      final result = await HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      ).read({HealthMetric.heartRate, HealthMetric.activeCalories}, now: day);
      expect(
        result.readings[HealthMetric.heartRate]!.status,
        HealthReadStatus.unsupported,
      );
      expect(
        result.readings[HealthMetric.activeCalories]!.status,
        HealthReadStatus.failed,
      );
    },
  );

  test(
    'iOS completed prompt does not prove read consent; empty iOS reads report unknown',
    () async {
      final sdk = TestHealth();
      final service = HealthService(health: sdk, platform: TargetPlatform.iOS);
      final initial = await service.read({HealthMetric.heartRate});
      expect(
        initial.readings[HealthMetric.heartRate]!.status,
        HealthReadStatus.notRequested,
      );
      expect(sdk.requested, isNull);
      final result = await service.read({
        HealthMetric.heartRate,
      }, requestPermissions: true);
      expect(
        result.readings[HealthMetric.heartRate]!.status,
        HealthReadStatus.permissionUnknown,
      );
      expect(result.readings[HealthMetric.heartRate]!.value, isNull);
      expect(sdk.requestedAccess, [HealthDataAccess.READ]);
    },
  );

  test(
    'revocation during a read removes the value instead of retaining earlier access',
    () async {
      final sdk = TestHealth()..revokeDuringRead = HealthDataType.STEPS;
      sdk.granted.add(HealthDataType.STEPS);
      sdk.data[HealthDataType.STEPS] = [
        sample(HealthDataType.STEPS, 5000, day),
      ];
      final result = await HealthService(
        health: sdk,
        platform: TargetPlatform.android,
      ).read({HealthMetric.steps}, now: day);
      expect(
        result.readings[HealthMetric.steps]!.status,
        HealthReadStatus.permissionRequired,
      );
      expect(result.readings[HealthMetric.steps]!.value, isNull);
    },
  );

  testWidgets(
    'health entry remains behind the authenticated shell and logout removes its route',
    (tester) async {
      final auth = await openApp(tester);
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(OutlinedButton, 'Sağlık Verileri');
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(HealthDataScreen), findsOneWidget);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(HealthDataScreen), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'screen asks no startup permission and deselected health types are not requested',
    (tester) async {
      final sdk = TestHealth()..allowRequest = false;
      await showHealth(tester, sdk);
      expect(sdk.requested, isNull);
      expect(
        find.textContaining('Bu veri için okuma izni verilmedi.'),
        findsNWidgets(3),
      );
      await tester.tap(find.byKey(const ValueKey('health-select-heartRate')));
      await tester.pumpAndSettle();
      await click(tester, 'İzin Ver ve Oku');
      expect(sdk.requested, [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ]);
      expect(find.text('0 adım'), findsNothing);
      expect(find.text('0 kcal'), findsNothing);
    },
  );

  testWidgets(
    'permission/loading disables repeat submission; empty grant has no invented values',
    (tester) async {
      final pending = Completer<void>();
      final sdk = TestHealth()..permissionPrompt = pending;
      await showHealth(tester, sdk);
      final button = find.widgetWithText(FilledButton, 'İzin Ver ve Oku');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Sağlık verileri kontrol ediliyor…'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bu zaman aralığında sağlık kaydı yok.'),
        findsNWidgets(3),
      );
      expect(find.text('0 adım'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'availability error is visible and retry works without an automatic permission prompt',
    (tester) async {
      final sdk = TestHealth()..failConfigure = true;
      await showHealth(tester, sdk);
      expect(
        find.textContaining('Sağlık platformuna erişilemedi.'),
        findsOneWidget,
      );
      sdk.failConfigure = false;
      await click(tester, 'Tekrar dene');
      expect(
        find.textContaining('Bu veri için okuma izni verilmedi.'),
        findsNWidgets(3),
      );
      expect(sdk.requested, isNull);
    },
  );

  testWidgets(
    'narrow layout with large text stays scrollable and exposes unavailable state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final sdk = TestHealth()..status = HealthConnectSdkStatus.sdkUnavailable;
      await showHealth(tester, sdk);
      await tester.ensureVisible(
        find.text(
          'Bu cihazda sağlık platformu desteklenmiyor veya kullanılamıyor.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
