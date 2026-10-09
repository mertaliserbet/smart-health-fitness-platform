import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/main.dart' as application;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real main shows Login and offline login error', (tester) async {
    // Use a closed, isolated port; never contact the user's development database.
    expect(AppConfig.fromEnvironment().apiBaseUrl.port, 5063);
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    application.main();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'offline@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'OfflinePassword123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    expect(find.textContaining('Backend’in açık'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
