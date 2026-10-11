import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/features/running/running_models.dart';
import 'package:smart_health_fitness_mobile/features/running/running_screen.dart';
import 'package:smart_health_fitness_mobile/features/running/running_service.dart';
import 'package:smart_health_fitness_mobile/features/running/running_tracker.dart';
import 'package:smart_health_fitness_mobile/features/running/running_tracking_screen.dart';

import 'auth_service_test.dart' show makeApi, jsonResponse, tokens;

class TestClock extends Stopwatch {
  Duration time = Duration.zero;
  bool running = false;
  @override
  Duration get elapsed => time;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
  void advance(int seconds) {
    if (running) time += Duration(seconds: seconds);
  }
}

class GpsFixture {
  DateTime now = DateTime.utc(2026, 1, 1);
  double latitude = 41;
  final clock = TestClock();
  final gps = StreamController<Position>.broadcast(sync: true);
  final services = StreamController<ServiceStatus>.broadcast(sync: true);
  late final tracker = RunningTracker(
    locate: () async => fix(),
    positions: () => gps.stream,
    services: () => services.stream,
    now: () => now,
    clock: clock,
  );
  Position fix({double accuracy = 5}) => Position(
    latitude: latitude,
    longitude: 29,
    timestamp: now,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  void move(int seconds, double lat, {double accuracy = 5}) {
    clock.advance(seconds);
    now = now.add(Duration(seconds: seconds));
    latitude = lat;
    gps.add(fix(accuracy: accuracy));
  }

  Future<void> dispose() async {
    tracker.dispose();
    await gps.close();
    await services.close();
  }
}

RunningDraft draft() => RunningDraft(
  id: 'ea6b9c55-b276-4df8-bf97-268efbce7498',
  startedAt: DateTime.utc(2026, 1, 1),
  endedAt: DateTime.utc(2026, 1, 1, 0, 0, 30),
  durationSeconds: 20,
  segments: [
    [
      RunningPoint(41, 29, 5, DateTime.utc(2026, 1, 1)),
      RunningPoint(41.0001, 29, 5, DateTime.utc(2026, 1, 1, 0, 0, 10)),
    ],
  ],
);
Map<String, dynamic> response(RunningDraft run) => {
  ...run.toJson(),
  'distanceMeters': run.distanceMeters,
  'averagePaceSecondsPerKm': run.pace,
  'averageSpeedKmh': run.speed,
  'estimatedCalories': null,
  'createdAt': run.endedAt.toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('GPS pause/resume excludes paused movement and duration', () async {
    final f = GpsFixture();
    addTearDown(f.dispose);
    await f.tracker.startOrResume();
    expect(f.tracker.state, RunningState.running);
    f.move(10, 41.0001);
    expect(f.tracker.distanceMeters, closeTo(11.13, .02));
    f.tracker.pause();
    f.move(20, 42);
    expect(f.tracker.durationSeconds, 10);
    expect(f.tracker.distanceMeters, closeTo(11.13, .02));
    await f.tracker.startOrResume();
    f.move(10, 42.0001);
    final run = f.tracker.finish()!;
    expect(run.durationSeconds, 20);
    expect(run.segments, hasLength(2));
    expect(run.distanceMeters, closeTo(22.26, .02));
    expect(run.speed, closeTo(4.0068, .02));
    expect(run.pace, closeTo(898.47, .1));
    expect(run.endedAt.difference(run.startedAt).inSeconds, 40);
    expect(f.clock.running, isFalse);
  });

  test(
    'jitter, weak fixes, GPS jumps and gaps cannot inflate distance',
    () async {
      final f = GpsFixture();
      addTearDown(f.dispose);
      await f.tracker.startOrResume();
      f.move(1, 41.000001);
      expect(f.tracker.distanceMeters, 0);
      f.move(1, 42);
      expect(f.tracker.distanceMeters, 0);
      f.move(1, 41.0002, accuracy: 80);
      expect(f.tracker.distanceMeters, 0);
      f.move(2, 41.0003);
      expect(f.tracker.distanceMeters, 0);
      f.move(10, 41.0004);
      expect(f.tracker.distanceMeters, closeTo(11.13, .02));
      f.move(16, 41.0005);
      expect(f.tracker.distanceMeters, closeTo(11.13, .02));
      expect(f.tracker.segments, hasLength(3));
    },
  );

  test(
    'GPS service loss pauses; background requires explicit resume',
    () async {
      final f = GpsFixture();
      addTearDown(f.dispose);
      await f.tracker.startOrResume();
      f.move(2, 41.0001);
      f.services.add(ServiceStatus.disabled);
      expect(f.tracker.state, RunningState.paused);
      expect(f.tracker.action, LocationAction.gps);
      f.tracker.setForeground(false);
      f.now = f.now.add(const Duration(seconds: 1));
      await f.tracker.startOrResume();
      expect(f.tracker.state, RunningState.paused);
      f.tracker.setForeground(true);
      await f.tracker.startOrResume();
      expect(f.tracker.state, RunningState.running);
    },
  );

  for (final action in LocationAction.values) {
    test('location failure $action never starts a timer or route', () async {
      final tracker = RunningTracker(
        locate: () async {
          throw RunningLocationException('Konum kullanılamıyor', action);
        },
      );
      addTearDown(tracker.dispose);
      await tracker.startOrResume();
      expect(tracker.state, RunningState.ready);
      expect(tracker.busy, isFalse);
      expect(tracker.action, action);
      expect(tracker.segments, isEmpty);
      expect(tracker.durationSeconds, 0);
    });
  }

  test('late location after dispose does not subscribe', () async {
    final located = Completer<Position>();
    final f = GpsFixture();
    addTearDown(f.dispose);
    var subscribed = false;
    final tracker = RunningTracker(
      locate: () => located.future,
      positions: () {
        subscribed = true;
        return f.gps.stream;
      },
    );
    final pending = tracker.startOrResume();
    tracker.dispose();
    located.complete(f.fix());
    await pending;
    expect(subscribed, isFalse);
  });

  testWidgets(
    'missing GPS automatically pauses and initial location has a timeout',
    (tester) async {
      final f = GpsFixture();
      addTearDown(f.dispose);
      await f.tracker.startOrResume();
      f.now = f.now.add(const Duration(seconds: 46));
      await tester.pump(const Duration(seconds: 1));
      expect(f.tracker.state, RunningState.paused);
      expect(f.tracker.message, contains('45 saniyedir'));
      final tracker = RunningTracker(
        locate: () => Completer<Position>().future,
      );
      addTearDown(tracker.dispose);
      final pending = tracker.startOrResume();
      expect(tracker.busy, isTrue);
      await tester.pump(const Duration(seconds: 21));
      await pending;
      expect(tracker.busy, isFalse);
      expect(tracker.state, RunningState.ready);
      expect(tracker.message, contains('Konum alınamadı'));
    },
  );

  test(
    'background during initial location cannot start a GPS stream',
    () async {
      final f = GpsFixture();
      addTearDown(f.dispose);
      final located = Completer<Position>();
      var subscribed = false;
      final tracker = RunningTracker(
        locate: () => located.future,
        now: () => f.now,
        positions: () {
          subscribed = true;
          return f.gps.stream;
        },
      );
      addTearDown(tracker.dispose);
      final pending = tracker.startOrResume();
      tracker.setForeground(false);
      located.complete(f.fix());
      await pending;
      expect(subscribed, isFalse);
      expect(tracker.state, RunningState.ready);
    },
  );

  test(
    'authenticated API and encrypted draft survive failed save/restart',
    () async {
      var fail = true;
      final api = makeApi((request) async {
        expect(request.headers['Authorization'], 'Bearer access-saved');
        expect(request.url.path, RunningService.path);
        if (request.method == 'GET') return jsonResponse([]);
        expect(jsonDecode(request.body), draft().toJson());
        return fail
            ? jsonResponse({'title': 'Unavailable'}, 503)
            : jsonResponse(response(draft()), 201);
      });
      addTearDown(api.close);
      await api.saveSession(tokens('saved'));
      final service = RunningService(api, 'user');
      await service.storeDraft(draft());
      await expectLater(service.save(draft()), throwsA(isA<ApiException>()));
      final restored = RunningService(api, 'user');
      expect((await restored.readDraft())!.id, draft().id);
      expect(await RunningService(api, 'other-user').readDraft(), isNull);
      expect(await service.getActivities(), isEmpty);
      fail = false;
      expect((await restored.save(draft())).id, draft().id);
      expect(await restored.readDraft(), isNull);
    },
  );

  testWidgets('offline history still opens pending run and can retry', (
    tester,
  ) async {
    final api = makeApi(
      (request) async => jsonResponse({'title': 'Unavailable'}, 503),
    );
    addTearDown(api.close);
    await api.saveSession(tokens('saved'));
    final service = RunningService(api, 'user');
    await service.storeDraft(draft());
    await tester.pumpWidget(MaterialApp(home: RunningScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş Koşuyu Aç'), findsOneWidget);
    await tester.tap(find.text('Kaydedilmemiş Koşuyu Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Koşu tamamlandı'), findsOneWidget);
    final retry = find.text('Kaydı Tekrar Dene');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect((await service.readDraft())!.id, draft().id);
    expect(find.textContaining('Özet bu cihazda saklandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreground GPS lifecycle and finishing save use live route', (
    tester,
  ) async {
    final f = GpsFixture();
    // The screen owns/disposes the tracker.
    addTearDown(() async {
      await f.gps.close();
      await f.services.close();
    });
    RunningDraft? posted;
    final api = makeApi((request) async {
      posted = RunningDraft.fromJson(
        jsonDecode(request.body) as Map<String, dynamic>,
      );
      return jsonResponse(response(posted!), 201);
    });
    addTearDown(api.close);
    await api.saveSession(tokens('saved'));
    await tester.pumpWidget(
      MaterialApp(
        home: RunningTrackingScreen(
          service: RunningService(api, 'user'),
          tracker: f.tracker,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başlat'));
    await tester.pump();
    await tester.pump();
    f.move(10, 41.0001);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(f.tracker.state, RunningState.paused);
    f.move(10, 42);
    expect(f.tracker.durationSeconds, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.ensureVisible(find.text('Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();
    expect(find.text('Koşu kaydedildi'), findsOneWidget);
    expect(posted!.durationSeconds, 10);
    expect(posted!.distanceMeters, closeTo(11.13, .02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow large text summary has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = makeApi((request) async => jsonResponse([]));
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: RunningTrackingScreen(
          service: RunningService(api, 'user'),
          draft: draft(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
