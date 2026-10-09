import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';

import 'auth_service_test.dart' show makeApi, jsonResponse;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'empty login and short registration password do not call backend',
    (tester) async {
      var requests = 0;
      final auth = AuthService(
        makeApi((request) async {
          requests++;
          return jsonResponse({});
        }),
      );
      await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.text('E-posta adresinizi girin.'), findsOneWidget);
      expect(find.text('Şifrenizi girin.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mert');
      await tester.enterText(fields.at(1), 'Test');
      await tester.enterText(fields.at(2), 'mert@example.test');
      await tester.enterText(fields.at(3), 'short');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Hesap Oluştur'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Hesap Oluştur'));
      await tester.pumpAndSettle();
      expect(find.text('Şifre en az 12 karakter olmalıdır.'), findsOneWidget);
      expect(requests, 0);
    },
  );

  testWidgets('wrong credentials show friendly error and retain inputs', (
    tester,
  ) async {
    final auth = AuthService(
      makeApi(
        (request) async =>
            jsonResponse({'title': 'Invalid email or password'}, 401),
      ),
    );
    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'mert@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    expect(find.text('mert@example.test'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsNothing);
  });
}
