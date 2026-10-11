import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';
import 'package:smart_health_fitness_mobile/features/nutrition/nutrition_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'manual meals → PostgreSQL → daily totals and active goal → history → isolation',
    (tester) async {
      expect(
        const bool.fromEnvironment('NUTRITION_TEST_FIXTURE'),
        isTrue,
        reason:
            'Use mobile/tool/auth_smoke.ps1 -NutritionTest, never a real user database.',
      );
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final config = AppConfig.fromEnvironment();
      final store = TokenStore(server: config.apiBaseUrl.toString());
      await store.clear();
      final api = ApiService(config, store);
      final auth = AuthService(api);
      await auth.login(
        'nutrition-user@example.test',
        'Nutrition-Test-Password123!',
      );
      await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Beslenme'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu gün için henüz beslenme kaydı yok.'),
        findsOneWidget,
      );
      expect(find.text('0 / 2000'), findsOneWidget);
      final meals = [
        {
          'name': 'Yulaf ve süt',
          'calories': '450,25',
          'proteinGrams': '20,5',
          'carbohydrateGrams': '60,25',
          'fatGrams': '12,5',
        },
        {
          'name': 'Tavuk ve pilav',
          'calories': '650,25',
          'proteinGrams': '48',
          'carbohydrateGrams': '72,75',
          'fatGrams': '16',
        },
      ];
      for (final meal in meals) {
        await tester.ensureVisible(find.text('Beslenme Kaydı Ekle'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beslenme Kaydı Ekle'));
        await tester.pumpAndSettle();
        for (final field in meal.entries) {
          await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
        }
        await tester.enterText(
          find.byKey(const ValueKey('portionDescription')),
          '1 porsiyon',
        );
        await tester.ensureVisible(find.text('Kaydet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('1100,5 / 2000'));
      expect(find.text('Kalan: 899,5'), findsOneWidget);
      final service = NutritionService(api);
      final day = await service.getDailySummary(DateTime.now());
      expect(day.recordCount, 2);
      expect(day.values['calories'], 1100.5);
      expect(day.values['proteinGrams'], 68.5);
      expect(day.values['carbohydrateGrams'], 133);
      expect(day.values['fatGrams'], 28.5);
      expect(day.goal!.targets['dailyCalories'], 2000);
      final records = await service.getRecords();
      expect(
        records.map((r) => r.name),
        containsAll(['Yulaf ve süt', 'Tavuk ve pilav']),
      );
      await tester.ensureVisible(find.text('Tavuk ve pilav'));
      expect(find.text('Tavuk ve pilav'), findsOneWidget);
      // A fresh API/session reads the persisted records, as after restarting the app.
      final restoredApi = ApiService(
        config,
        TokenStore(server: config.apiBaseUrl.toString()),
      );
      await restoredApi.loadSession();
      expect((await NutritionService(restoredApi).getRecords()).length, 2);
      restoredApi.close();
      await auth.logout();
      await tester.pumpAndSettle();
      await auth.login(
        'nutrition-other@example.test',
        'Nutrition-Test-Password123!',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Beslenme'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu gün için henüz beslenme kaydı yok.'),
        findsOneWidget,
      );
      expect(find.text('Tavuk ve pilav'), findsNothing);
      expect(await service.getRecords(), isEmpty);
      expect((await service.getDailySummary(DateTime.now())).goal, isNull);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
