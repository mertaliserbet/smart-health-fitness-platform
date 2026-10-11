import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_health_fitness_mobile/app.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';
import 'package:smart_health_fitness_mobile/features/running/running_models.dart';
import 'package:smart_health_fitness_mobile/features/running/running_service.dart';

Future<void> until(
  WidgetTester tester,
  bool Function() ready, {
  int seconds = 40,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    ready(),
    isTrue,
    reason:
        'Native GPS / HTTP state did not become ready. Visible texts: '
        '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(' | ')}',
  );
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android GPS → pause/resume → PostgreSQL → own history/detail', (
    tester,
  ) async {
    expect(
      const bool.fromEnvironment('RUNNING_TEST_FIXTURE'),
      isTrue,
      reason:
          'Use mobile/tool/auth_smoke.ps1 -RunningTest with its isolated database.',
    );
    final config = AppConfig.fromEnvironment();
    final store = TokenStore(server: config.apiBaseUrl.toString());
    await store.clear();
    final api = ApiService(config, store);
    final auth = AuthService(api);
    const password = 'Running-Test-Password123!';
    for (final name in ['user', 'other']) {
      await auth.register(
        firstName: 'Çağrı',
        lastName: 'Şerbet',
        email: 'running-$name@example.test',
        password: password,
      );
    }
    await auth.login('running-user@example.test', password);
    final service = RunningService(api, auth.user!.id);
    await service.clearDraft();
    await tester.pumpWidget(SmartHealthFitnessApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tap(tester, 'Koşu');
    await until(
      tester,
      () => find.text('Henüz koşu kaydı yok.').evaluate().isNotEmpty,
    );
    await tap(tester, 'Koşuyu Başlat');
    // Host test helper grants actual Android permissions, never mocks the plugin.
    var permission = await Geolocator.checkPermission();
    for (
      var attempt = 0;
      attempt < 20 &&
          permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always;
      attempt++
    ) {
      await tester.pump(const Duration(seconds: 1));
      permission = await Geolocator.checkPermission();
    }
    expect([
      LocationPermission.whileInUse,
      LocationPermission.always,
    ], contains(permission));
    debugPrint(
      'Emulator GPS: service=${await Geolocator.isLocationServiceEnabled()}, '
      'accuracy=${await Geolocator.getLocationAccuracy()}, '
      'lastFix=${await Geolocator.getLastKnownPosition()}',
    );
    await tap(tester, 'Başlat');
    debugPrint('GPS TEST: start pressed');
    await until(tester, () => find.text('Koşu sürüyor').evaluate().isNotEmpty);
    debugPrint('GPS TEST: recording');
    // Record through the production screen/plugin, using host-injected emulator GPS.
    await tester.pump(const Duration(seconds: 10));
    await tap(tester, 'Duraklat');
    debugPrint('GPS TEST: paused');
    expect(find.text('Koşu duraklatıldı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, 'Devam Et');
    debugPrint('GPS TEST: resume pressed');
    await until(tester, () => find.text('Koşu sürüyor').evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 8));
    await tap(tester, 'Bitir');
    debugPrint('GPS TEST: finish pressed');
    await until(
      tester,
      () => find.text('Koşu kaydedildi').evaluate().isNotEmpty,
    );
    final runs = await service.getActivities();
    expect(runs, hasLength(1));
    expect(runs.single.distanceMeters, greaterThan(0));
    expect(runs.single.durationSeconds, greaterThanOrEqualTo(17));
    final detail = await service.getActivity(runs.single.id);
    expect(detail.segments, hasLength(2));
    expect(detail.segments!.expand((s) => s).length, greaterThanOrEqualTo(4));
    expect(
      detail.endedAt.difference(detail.startedAt).inSeconds -
          detail.durationSeconds,
      greaterThanOrEqualTo(2),
    );
    expect(
      detail.distanceMeters,
      closeTo(runningDistance(detail.segments!), .01),
    );
    expect(
      detail.speed,
      closeTo(detail.distanceMeters * 3.6 / detail.durationSeconds, .01),
    );
    final retry = RunningDraft(
      id: detail.id,
      startedAt: detail.startedAt,
      endedAt: detail.endedAt,
      durationSeconds: detail.durationSeconds,
      segments: detail.segments!,
    );
    expect((await service.save(retry)).id, detail.id);
    expect(await service.getActivities(), hasLength(1));
    await tap(tester, 'Koşu Geçmişine Dön');
    await until(
      tester,
      () => find.text('Koşu Detayını Gör').evaluate().isNotEmpty,
    );
    await tap(tester, 'Koşu Detayını Gör');
    await until(
      tester,
      () => find.textContaining('Başlangıç:').evaluate().isNotEmpty,
    );
    expect(find.text('Koşu Detayı'), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    await auth.login('running-other@example.test', password);
    await tester.pumpAndSettle();
    final other = RunningService(api, auth.user!.id);
    expect(await other.getActivities(), isEmpty);
    await expectLater(
      other.getActivity(detail.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect(await other.readDraft(), isNull);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Giriş Yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
