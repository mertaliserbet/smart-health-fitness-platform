import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_service.dart';
import 'package:smart_health_fitness_mobile/features/running/running_models.dart';
import 'package:smart_health_fitness_mobile/features/running/running_service.dart';
import 'package:smart_health_fitness_mobile/features/tracking/tracking_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'PostgreSQL records → native tracking charts / filters / goal / run totals → isolation',
    (tester) async {
      expect(
        const bool.fromEnvironment('TRACKING_PROGRESS_TEST_FIXTURE'),
        isTrue,
        reason:
            'Use mobile/tool/auth_smoke.ps1 -TrackingProgressTest; never the user database.',
      );
      final config = AppConfig.fromEnvironment();
      final store = TokenStore(server: config.apiBaseUrl.toString());
      await store.clear();
      final api = ApiService(config, store);
      final auth = AuthService(api);
      await auth.login(
        'nutrition-user@example.test',
        'Nutrition-Test-Password123!',
      );
      final tracking = TrackingService(api);
      final nutrition = NutritionService(api);
      final running = RunningService(api, auth.user!.id);
      final now = DateTime.now();
      // Fixtures are written through existing HTTP APIs into the disposable DB.
      // No production seed or synthetic data fallback is added to the application.
      for (final day in [45, 29, 6, 0]) {
        final date = DateTime(now.year, now.month, now.day - day);
        await tracking.createWeightRecord(80 + day / 10, date);
        await tracking.createBodyMeasurement({
          'waistCm': 85 + day / 10,
          'bodyFatPercentage': 20 + day / 10,
        }, date);
        await running.save(
          RunningDraft(
            id: RunningDraft.newId(),
            startedAt: date.toUtc(),
            endedAt: date.add(const Duration(seconds: 10)).toUtc(),
            durationSeconds: 10,
            segments: [
              [
                RunningPoint(41, 29, 5, date.toUtc()),
                RunningPoint(
                  41.0001,
                  29,
                  5,
                  date.add(const Duration(seconds: 10)).toUtc(),
                ),
              ],
            ],
          ),
        );
      }
      await nutrition.createRecord(
        mealType: 'Lunch',
        name: 'Entegrasyon öğünü',
        values: {
          'calories': 1100.5,
          'proteinGrams': 68.5,
          'carbohydrateGrams': 133,
          'fatGrams': 28.5,
        },
        consumedAt: now.subtract(const Duration(seconds: 1)),
      );
      await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      expect(find.text('30 gün • 3 kayıt'), findsOneWidget);
      expect(find.text('Değişim: -2,9 kg'), findsOneWidget);
      expect(find.text('1100,5 / 2000'), findsOneWidget);
      expect(find.text('68,5 / 100'), findsOneWidget);
      expect(find.text('133 / 250'), findsOneWidget);
      expect(find.text('28,5 / 70'), findsOneWidget);
      expect(find.text('30 gün • 3 koşu'), findsOneWidget);
      expect(find.text('Toplam aktif süre: 0:00:30'), findsOneWidget);
      expect(find.text('Toplam mesafe: 0,03 km'), findsOneWidget);

      Future<void> reveal(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
      }

      for (final title in [
        'Güncel kilo',
        'Vücut ölçümü gelişimi',
        'Günlük kalori ve makrolar',
        'Koşu özeti',
      ]) {
        await reveal(title);
        expect(tester.takeException(), isNull);
      }
      Future<void> choose(String label) async {
        final chip = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await choose('7 gün');
      expect(find.text('7 gün • 2 kayıt'), findsOneWidget);
      expect(find.text('Değişim: -0,6 kg'), findsOneWidget);
      expect(find.text('7 gün • 2 koşu'), findsOneWidget);
      expect(find.text('Toplam aktif süre: 0:00:20'), findsOneWidget);
      await choose('Tüm zamanlar');
      expect(find.text('Tüm zamanlar • 4 kayıt'), findsOneWidget);
      expect(find.text('Tüm zamanlar • 4 koşu'), findsOneWidget);
      expect(find.text('Toplam aktif süre: 0:00:40'), findsOneWidget);
      final dropdown = find.byKey(const ValueKey('progress-measurement'));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vücut yağ oranı').last);
      await tester.pumpAndSettle();
      expect(find.text('Değişim: -4,5 yüzde puan'), findsOneWidget);
      // Check a fresh authenticated API instance reads persisted PostgreSQL records.
      final restored = ApiService(
        config,
        TokenStore(server: config.apiBaseUrl.toString()),
      );
      await restored.loadSession();
      expect((await TrackingService(restored).getWeightRecords()).length, 4);
      restored.close();
      await auth.logout();
      await tester.pumpAndSettle();
      await auth.login(
        'nutrition-other@example.test',
        'Nutrition-Test-Password123!',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      expect(find.text('Henüz kilo kaydı yok'), findsOneWidget);
      expect(find.text('Henüz vücut ölçümü kaydı yok.'), findsOneWidget);
      expect(
        find.text('Bu gün için henüz beslenme kaydı yok.'),
        findsOneWidget,
      );
      expect(find.text('Henüz koşu kaydı yok.'), findsOneWidget);
      expect(find.text('1100,5 / 2000'), findsNothing);
      expect(await tracking.getWeightRecords(), isEmpty);
      expect(await running.getActivities(), isEmpty);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
