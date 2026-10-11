import 'dart:math';

import 'package:geolocator/geolocator.dart';

class RunningPoint {
  const RunningPoint(
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.recordedAt,
  );
  factory RunningPoint.fromJson(Map<String, dynamic> json) => RunningPoint(
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
    (json['accuracyMeters'] as num).toDouble(),
    DateTime.parse(json['recordedAt'] as String).toUtc(),
  );
  final double latitude, longitude, accuracyMeters;
  final DateTime recordedAt;
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };
  double distanceTo(RunningPoint other) => Geolocator.distanceBetween(
    latitude,
    longitude,
    other.latitude,
    other.longitude,
  );
}

List<List<RunningPoint>> runningSegments(Map<String, dynamic> route) {
  if (route['type'] != 'gps-segments') {
    throw const FormatException('Unknown running route');
  }
  return (route['segments'] as List)
      .map(
        (segment) => (segment as List)
            .map(
              (point) => RunningPoint.fromJson(point as Map<String, dynamic>),
            )
            .toList(),
      )
      .toList();
}

double runningDistance(List<List<RunningPoint>> segments) {
  var distance = 0.0;
  for (final segment in segments) {
    for (var index = 1; index < segment.length; index++) {
      distance += segment[index - 1].distanceTo(segment[index]);
    }
  }
  return distance;
}

class RunningDraft {
  const RunningDraft({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.segments,
  });
  factory RunningDraft.fromJson(Map<String, dynamic> json) => RunningDraft(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
    endedAt: DateTime.parse(json['endedAt'] as String).toUtc(),
    durationSeconds: json['durationSeconds'] as int,
    segments: runningSegments(json['routeData'] as Map<String, dynamic>),
  );
  final String id;
  final DateTime startedAt, endedAt;
  final int durationSeconds;
  final List<List<RunningPoint>> segments;
  double get distanceMeters =>
      double.parse(runningDistance(segments).toStringAsFixed(2));
  double? get pace =>
      distanceMeters == 0 ? null : durationSeconds * 1000 / distanceMeters;
  double get speed =>
      durationSeconds == 0 ? 0 : distanceMeters * 3.6 / durationSeconds;
  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'routeData': {
      'type': 'gps-segments',
      'segments': [
        for (final segment in segments)
          [for (final point in segment) point.toJson()],
      ],
    },
  };

  static String newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class RunningActivity {
  RunningActivity.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      startedAt = DateTime.parse(json['startedAt'] as String).toLocal(),
      endedAt = DateTime.parse(json['endedAt'] as String).toLocal(),
      durationSeconds = json['durationSeconds'] as int,
      distanceMeters = (json['distanceMeters'] as num).toDouble(),
      pace = (json['averagePaceSecondsPerKm'] as num?)?.toDouble(),
      speed = (json['averageSpeedKmh'] as num).toDouble(),
      segments = json['routeData'] == null
          ? null
          : runningSegments(json['routeData'] as Map<String, dynamic>) {
    if (durationSeconds <= 0 ||
        !distanceMeters.isFinite ||
        distanceMeters < 0 ||
        !speed.isFinite ||
        speed < 0 ||
        pace != null && (!pace!.isFinite || pace! < 0)) {
      throw const FormatException('Invalid running metrics');
    }
  }
  final String id;
  final DateTime startedAt, endedAt;
  final int durationSeconds;
  final double distanceMeters, speed;
  final double? pace;
  final List<List<RunningPoint>>? segments;
}

String runningDuration(int seconds) =>
    '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
String runningPace(double? seconds) => seconds == null
    ? '—'
    : '${seconds.round() ~/ 60}:${(seconds.round() % 60).toString().padLeft(2, '0')} dk/km';
