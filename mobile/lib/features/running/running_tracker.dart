import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'running_models.dart';

enum RunningState { ready, running, paused, finished }

enum LocationAction { permission, gps }

class RunningLocationException implements Exception {
  const RunningLocationException(this.message, [this.action]);
  final String message;
  final LocationAction? action;
}

class RunningTracker extends ChangeNotifier {
  RunningTracker({
    Future<Position> Function()? locate,
    Stream<Position> Function()? positions,
    Stream<ServiceStatus> Function()? services,
    Stopwatch? clock,
    DateTime Function()? now,
  }) : _locate = locate ?? _locateDevice,
       _positions = positions ?? _devicePositions,
       _services = services ?? Geolocator.getServiceStatusStream,
       _clock = clock ?? Stopwatch(),
       _now = now ?? DateTime.now;

  final Future<Position> Function() _locate;
  final Stream<Position> Function() _positions;
  final Stream<ServiceStatus> Function() _services;
  final Stopwatch _clock;
  final DateTime Function() _now;
  final List<List<RunningPoint>> _segments = [];
  StreamSubscription<Position>? _gps;
  StreamSubscription<ServiceStatus>? _service;
  Timer? _timer;
  DateTime? _startedAt, _lastFixAt;
  RunningPoint? _previous;
  String? _id;
  bool _disposed = false, _newSegment = false;
  bool _foreground = true;
  bool busy = false;
  RunningState state = RunningState.ready;
  String? message;
  LocationAction? action;
  RunningDraft? draft;
  int get durationSeconds => min(_clock.elapsed.inSeconds, 86400);
  List<List<RunningPoint>> get segments => [
    for (final segment in _segments) List.unmodifiable(segment),
  ];
  double get distanceMeters => runningDistance(_segments);
  double? get pace => distanceMeters == 0 || durationSeconds == 0
      ? null
      : durationSeconds * 1000 / distanceMeters;
  double get speed =>
      durationSeconds == 0 ? 0 : distanceMeters * 3.6 / durationSeconds;

  static LocationSettings _settings({Duration? timeLimit}) =>
      defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          timeLimit: timeLimit,
        )
      : LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: timeLimit,
        );
  static Stream<Position> _devicePositions() =>
      Geolocator.getPositionStream(locationSettings: _settings());
  static Future<Position> _locateDevice() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const RunningLocationException(
        'GPS kapalı. Konumu açıp tekrar deneyin.',
        LocationAction.gps,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw const RunningLocationException(
        'Koşu takibi için konum izni gerekli. Uygulama ayarlarından izin verebilirsin.',
        LocationAction.permission,
      );
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      throw const RunningLocationException(
        'Koşu mesafesi için kesin konum iznini açın.',
        LocationAction.permission,
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: _settings(timeLimit: const Duration(seconds: 15)),
    );
  }

  Future<void> startOrResume() async {
    if (busy || ![RunningState.ready, RunningState.paused].contains(state)) {
      return;
    }
    if (durationSeconds >= 86400 ||
        _segments.fold<int>(0, (count, segment) => count + segment.length) >=
            20000) {
      message = 'Koşu sınırına ulaştı. Koşuyu bitir.';
      _notify();
      return;
    }
    busy = true;
    message = 'Konum alınıyor…';
    action = null;
    _notify();
    try {
      final position = await _locate().timeout(const Duration(seconds: 20));
      if (_disposed) return;
      if (!_foreground) {
        message = 'Takip için uygulamaya dönüp tekrar başlat veya devam et.';
        return;
      }
      if (!_valid(position)) {
        throw const RunningLocationException(
          'Hassas ve güncel GPS konumu bekleniyor. Açık alanda tekrar deneyin.',
        );
      }
      if (_segments.isNotEmpty &&
          !position.timestamp.toUtc().isAfter(_segments.last.last.recordedAt)) {
        throw const RunningLocationException(
          'Yeni GPS konumu bekleniyor. Tekrar deneyin.',
        );
      }
      if (_startedAt == null) {
        _startedAt = position.timestamp.toUtc();
        _id = RunningDraft.newId();
      }
      _previous = null;
      _newSegment = true;
      state = RunningState.running;
      message = null;
      _accept(position);
      _clock.start();
      _gps = _positions().listen(
        _accept,
        onError: (Object error) {
          pause('Konum alınamadı. GPS ve izni kontrol edip devam et.');
        },
        onDone: () {
          if (state == RunningState.running) {
            pause('GPS bağlantısı durdu. Tekrar devam et.');
          }
        },
      );
      _service = _services().listen(
        (status) {
          if (status == ServiceStatus.disabled) {
            action = LocationAction.gps;
            pause('GPS kapandı. Konumu açıp devam et.');
          }
        },
        onError: (Object error) {
          pause('GPS durumu okunamadı. Tekrar devam et.');
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_now().toUtc().difference(_lastFixAt!).inSeconds >= 45) {
          pause(
            '45 saniyedir güvenilir GPS konumu alınamadı. Takip duraklatıldı.',
          );
        } else if (durationSeconds >= 86400) {
          pause('Koşu 24 saat sınırına ulaştı. Koşuyu bitir.');
        } else {
          _notify();
        }
      });
    } on RunningLocationException catch (error) {
      message = error.message;
      action = error.action;
    } on Object {
      if (state == RunningState.running) pause();
      message =
          'Konum alınamadı. GPS, izin ve bağlantıyı kontrol edip tekrar deneyin.';
    } finally {
      busy = false;
      _notify();
    }
  }

  bool _valid(Position position) =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude.abs() <= 90 &&
      position.longitude.abs() <= 180 &&
      position.accuracy.isFinite &&
      position.accuracy >= 0 &&
      position.accuracy <= 35 &&
      !_now().toUtc().isBefore(position.timestamp.toUtc()) &&
      _now().toUtc().difference(position.timestamp.toUtc()).inSeconds <= 10;

  void _accept(Position position) {
    if (_disposed || state != RunningState.running) return;
    if (!_valid(position)) {
      _newSegment = true;
      _previous = null;
      message = 'GPS konumu zayıf veya eski; bu nokta rotaya eklenmedi.';
      _notify();
      return;
    }
    final point = RunningPoint(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp.toUtc(),
    );
    if (_segments.isNotEmpty &&
        !point.recordedAt.isAfter(_segments.last.last.recordedAt)) {
      return;
    }
    _lastFixAt = _now().toUtc();
    final previous = _previous;
    if (previous != null) {
      final seconds =
          point.recordedAt.difference(previous.recordedAt).inMilliseconds /
          1000;
      final distance = previous.distanceTo(point);
      if (distance / seconds > 12) {
        _newSegment = true;
        _previous = null;
        message = 'GPS sıçraması algılandı; mesafeye eklenmedi.';
        _notify();
        return;
      }
      if (seconds > 15) {
        _newSegment = true;
      } else if (distance <
          max(3, (previous.accuracyMeters + point.accuracyMeters) / 2)) {
        message = null;
        return;
      }
    }
    if (_segments.fold<int>(0, (count, segment) => count + segment.length) >=
        20000) {
      pause('Rota 20000 nokta sınırına ulaştı. Koşuyu bitir.');
      return;
    }
    if (_newSegment) {
      _segments.add([]);
      _newSegment = false;
    }
    _segments.last.add(point);
    _previous = point;
    message = null;
    _notify();
  }

  void pause([String? reason]) {
    if (state != RunningState.running) return;
    _clock.stop();
    state = RunningState.paused;
    _timer?.cancel();
    _timer = null;
    _gps?.cancel();
    _gps = null;
    _service?.cancel();
    _service = null;
    _previous = null;
    message = reason;
    _notify();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      pause(
        'Uygulama arka plana geçti; koşu duraklatıldı. Devam etmek için uygulamaya dön.',
      );
    }
  }

  RunningDraft? finish() {
    if (busy || ![RunningState.running, RunningState.paused].contains(state)) {
      return null;
    }
    if (durationSeconds < 1) {
      message = 'En az bir saniyelik koşu gerekli.';
      _notify();
      return null;
    }
    pause();
    state = RunningState.finished;
    draft = RunningDraft(
      id: _id!,
      startedAt: _startedAt!,
      endedAt: _now().toUtc(),
      durationSeconds: durationSeconds,
      segments: segments,
    );
    _notify();
    return draft;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock.stop();
    _timer?.cancel();
    _gps?.cancel();
    _service?.cancel();
    super.dispose();
  }
}
