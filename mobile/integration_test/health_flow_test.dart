import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/core/app_theme.dart';
import 'package:smart_health_fitness_mobile/features/health/health_data_screen.dart';
import 'package:smart_health_fitness_mobile/features/health/health_models.dart';
import 'package:smart_health_fitness_mobile/features/health/health_service.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native support → read-only permission denial → partial grant → empty/real data; revoked permissions after restart',
    (tester) async {
      expect(
        const bool.fromEnvironment('HEALTH_NATIVE_TEST'),
        isTrue,
        reason:
            'Use an Android test emulator; native permission actions are required. No test health records are written.',
      );
      final service = HealthService();
      final initial = await service.read(HealthMetric.values.toSet());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HealthDataScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      if (initial.availability != HealthAvailability.available) {
        expect(
          find.textContaining(
            initial.availability == HealthAvailability.installRequired
                ? 'Health Connect kurulmalı'
                : 'Bu cihazda sağlık platformu desteklenmiyor',
          ),
          findsOneWidget,
        );
        debugPrint('HEALTH_NATIVE_UNAVAILABLE: ${initial.availability.name}');
        return;
      }
      expect(
        initial.readings.values.map((r) => r.status),
        everyElement(HealthReadStatus.permissionRequired),
        reason:
            'Revoke this test app’s three health READ permissions before starting.',
      );
      if (const bool.fromEnvironment('HEALTH_NATIVE_REVOKED')) {
        expect(
          find.textContaining('Bu veri için okuma izni verilmedi.'),
          findsNWidgets(3),
        );
        expect(find.text('0 adım'), findsNothing);
        expect(tester.takeException(), isNull);
        debugPrint(
          'HEALTH_NATIVE_REVOKED_PASS: restarted app has no health access or retained values.',
        );
        return;
      }
      final permissionButton = find.widgetWithText(
        FilledButton,
        'İzin Ver ve Oku',
      );
      await tester.ensureVisible(permissionButton);
      await tester.pumpAndSettle();
      await tester.tap(permissionButton);
      await tester.pump();
      debugPrint(
        'HEALTH_NATIVE_PERMISSION_PROMPT: decline/back in the native OS dialog.',
      );
      for (var attempt = 0; attempt < 180; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pump();
        if (tester.widget<FilledButton>(permissionButton).onPressed != null) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bu veri için okuma izni verilmedi.'),
        findsNWidgets(3),
      );
      debugPrint(
        'HEALTH_NATIVE_GRANT_STEPS: grant only android.permission.health.READ_STEPS via adb.',
      );
      Future<HealthMetricReading> waitForGrant(bool granted) async {
        for (var attempt = 0; attempt < 120; attempt++) {
          final result = (await service.read({
            HealthMetric.steps,
          })).readings[HealthMetric.steps]!;
          if ((result.status != HealthReadStatus.permissionRequired) ==
              granted) {
            return result;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
        }
        throw StateError(
          'Native READ_STEPS permission action was not received.',
        );
      }

      final allowed = await waitForGrant(true);
      expect(
        allowed.status,
        isIn([HealthReadStatus.data, HealthReadStatus.noData]),
      );
      final refresh = find.widgetWithText(OutlinedButton, 'Yenile');
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      if (allowed.status == HealthReadStatus.noData) {
        expect(
          find.textContaining('Bu zaman aralığında sağlık kaydı yok.'),
          findsOneWidget,
        );
        expect(find.text('0 adım'), findsNothing);
      } else {
        expect(
          find.text('${trackingNumber(allowed.value!)} adım'),
          findsOneWidget,
        );
      }
      expect(
        find.textContaining('Bu veri için okuma izni verilmedi.'),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'HEALTH_NATIVE_PASS: no synthetic health data; permission changes reflected by real Health Connect.',
      );
    },
  );
}
