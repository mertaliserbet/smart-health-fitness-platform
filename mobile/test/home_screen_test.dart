import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_fitness_mobile/features/home/dashboard_widgets.dart';
import 'package:smart_health_fitness_mobile/features/home/home_screen.dart';

import 'app_shell_test.dart' show openApp;
import 'auth_service_test.dart' show jsonResponse, userJson;

const cardTitles = [
  'Bugünkü antrenman',
  'Kalori / makro özeti',
  'Günlük aktivite',
  'Kilo gelişimi',
  'Koç / diyetisyen',
];

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('dashboard uses me and empty summaries without module requests', (
    tester,
  ) async {
    final requests = <String>[];
    await openApp(
      tester,
      handler: (request) async {
        requests.add(request.url.path);
        return jsonResponse({...userJson, 'firstName': 'Çağrı'});
      },
    );
    expect(find.text('Merhaba, Çağrı'), findsOneWidget);
    expect(find.textContaining('${DateTime.now().year}'), findsOneWidget);
    expect(find.byType(DashboardCard), findsNWidgets(5));
    for (final title in cardTitles) {
      await tester.ensureVisible(find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    for (final label in [
      'Kalori',
      'Protein',
      'Karbonhidrat',
      'Yağ',
      'Adım',
      'Aktif kalori',
      'Son kilo',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Veri yok'), findsNWidgets(7));
    for (final message in [
      'Henüz antrenman verisi yok',
      'Henüz beslenme verisi yok',
      'Henüz aktivite verisi yok',
      'Henüz kilo verisi yok',
      'Henüz koç bilgisi yok.',
      'Henüz diyetisyen bilgisi yok.',
    ]) {
      expect(find.text(message), findsOneWidget);
    }
    expect(find.text('Antrenmanı Başlat'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(requests, ['/api/users/me']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard actions select existing tabs and preserve Home scroll',
    (tester) async {
      await openApp(tester);
      final homeScroll = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final action in {
        'Planıma Git': 1,
        'Beslenme Planıma Git': 1,
        'Aktivite için Takibe Git': 3,
        'Kilo için Takibe Git': 3,
        'Rehberime Git': 4,
      }.entries) {
        final button = find.text(action.key);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final before = tester
            .state<ScrollableState>(homeScroll)
            .position
            .pixels;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          action.value,
        );
        await tester.tap(find.byType(NavigationDestination).first);
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(homeScroll).position.pixels,
          before,
        );
      }
      await tester.tap(find.byTooltip('Profil ve Ayarlar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Profil ve Ayarlar'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 480),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('dashboard fits $size with long name and large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(
        tester,
        handler: (_) async => jsonResponse({
          ...userJson,
          'firstName': 'Çağrı Mert Ali Uzun Bir İsim',
        }),
      );
      for (final title in cardTitles) {
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Rehberime Git'));
      await tester.tap(find.text('Rehberime Git'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide dashboard arranges summary cards in two columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openApp(tester);
    final nutrition = tester.getTopLeft(find.text('Kalori / makro özeti'));
    final activity = tester.getTopLeft(find.text('Günlük aktivite'));
    expect(activity.dy, nutrition.dy);
    expect(activity.dx, greaterThan(nutrition.dx));
    await tester.ensureVisible(find.text('Koç / diyetisyen'));
    expect(tester.takeException(), isNull);
  });
}
