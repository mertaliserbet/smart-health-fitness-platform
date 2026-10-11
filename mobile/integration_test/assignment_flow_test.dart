import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';
import 'package:smart_health_fitness_mobile/features/navigation/app_shell.dart';
import 'package:smart_health_fitness_mobile/features/plans/my_plan_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real PostgreSQL → Planım/Rehberim → logout → other user isolation',
    (tester) async {
      expect(
        const bool.fromEnvironment('ASSIGNMENT_TEST_FIXTURE'),
        isTrue,
        reason:
            'Run tool/auth_smoke.ps1 -AssignmentTest; never use a user database.',
      );
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final config = AppConfig.fromEnvironment();
      final store = TokenStore(server: config.apiBaseUrl.toString());
      await store.clear();
      final api = ApiService(config, store);
      await tester.pumpWidget(SmartHealthFitnessApp(auth: AuthService(api)));
      await tester.pumpAndSettle();
      await login(tester, 'assignment-user@example.test');
      await tab(tester, 1);
      expect(find.text('Atanmış kuvvet programı'), findsOneWidget);
      expect(find.text('Geçmiş program'), findsWidgets);
      expect(find.text('Diğer kullanıcının programı'), findsNothing);
      await tester.ensureVisible(find.text('Programı Gör').first);
      await tester.tap(find.text('Programı Gör').first);
      await settle(tester);
      expect(find.byType(WorkoutPlanDetailScreen), findsOneWidget);
      expect(find.text('Pazartesi • Kuvvet'), findsOneWidget);
      await tester.ensureVisible(find.text('Dinlenme: 90 sn'));
      expect(find.text('Set: 3'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Beslenme'));
      await settle(tester);
      expect(find.text('Kalori hedefi (kcal): 2300'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Görevler'));
      await settle(tester);
      expect(find.text('Esneme yap'), findsOneWidget);
      expect(find.text('Başkasının görevi'), findsNothing);
      await tester.ensureVisible(find.text('Koç notu'));
      expect(find.text('Hareketleri kontrollü yap.'), findsOneWidget);
      await tab(tester, 4);
      expect(find.text('Çağrı Şerbet'), findsOneWidget);
      expect(find.text('Kuvvet koçu'), findsOneWidget);
      await tester.ensureVisible(find.text('Diyetisyen • Dietitian'));
      expect(find.text('İrem Şerbet'), findsOneWidget);

      await tab(tester, 0);
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await settle(tester);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Çıkış Yap'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış Yap'));
      await settle(tester);
      expect(await store.read(), isNull);
      await login(tester, 'assignment-other@example.test');
      await tab(tester, 1);
      expect(find.text('Diğer kullanıcının programı'), findsOneWidget);
      expect(find.text('Atanmış kuvvet programı'), findsNothing);
      await expectLater(
        api.get('/api/workout-plans/10000000-0000-0000-0000-000000000005'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            404,
          ),
        ),
      );
      await tab(tester, 4);
      expect(find.text('Henüz koç atanmadı.'), findsOneWidget);
      expect(find.text('Henüz diyetisyen atanmadı.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await api.logout();
    },
  );
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 45),
);

Future<void> tab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NavigationDestination).at(index));
  await settle(tester);
}

Future<void> login(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'Assignment-Test-Password123!',
  );
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Giriş Yap'));
  await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
  await settle(tester);
  expect(find.byType(AppShell), findsOneWidget);
}
