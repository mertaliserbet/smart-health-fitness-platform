import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import 'health_models.dart';

class HealthService {
  HealthService({Health? health, TargetPlatform? platform})
    : _health = health ?? Health(),
      _platform = platform ?? defaultTargetPlatform;

  final Health _health;
  final TargetPlatform _platform;
  bool _configured = false;
  final _iosPrompted = <HealthMetric>{};
  static const _timeout = Duration(seconds: 20);
  static const _types = {
    HealthMetric.steps: HealthDataType.STEPS,
    HealthMetric.activeCalories: HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthMetric.heartRate: HealthDataType.HEART_RATE,
  };
  String get platformName =>
      _platform == TargetPlatform.iOS ? 'HealthKit' : 'Health Connect';

  Future<HealthAvailability> _availability() async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS].contains(_platform)) {
      return HealthAvailability.unsupported;
    }
    if (!_configured) {
      await _health.configure().timeout(_timeout);
      _configured = true;
    }
    if (_platform == TargetPlatform.android) {
      final status = await _health.getHealthConnectSdkStatus().timeout(
        _timeout,
      );
      if (status == null) {
        throw const HealthReadException(
          'Health Connect durumu okunamadı. Tekrar deneyin.',
        );
      }
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthAvailability.installRequired,
        HealthConnectSdkStatus.sdkUnavailable => HealthAvailability.unsupported,
      };
    }
    // health 13.3.2 exposes this native HealthKit availability check but has no
    // public Dart wrapper. It does not request permission or read health data.
    final available = await const MethodChannel(
      'flutter_health',
    ).invokeMethod<bool>('checkIfHealthDataAvailable').timeout(_timeout);
    return available == true
        ? HealthAvailability.available
        : HealthAvailability.unsupported;
  }

  Future<HealthSnapshot> read(
    Set<HealthMetric> selected, {
    bool requestPermissions = false,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toLocal();
    final day = DateTime(at.year, at.month, at.day);
    final availability = await _availability();
    if (availability != HealthAvailability.available) {
      return HealthSnapshot(
        availability: availability,
        platform: platformName,
        day: day,
        readAt: at,
        readings: const {},
      );
    }
    final supported = selected
        .where((metric) => _health.isDataTypeAvailable(_types[metric]!))
        .toList();
    if (requestPermissions && supported.isNotEmpty) {
      final missing = <HealthMetric>[];
      for (final metric in supported) {
        if (_platform == TargetPlatform.iOS || !await _allowed(metric)) {
          missing.add(metric);
        }
      }
      if (missing.isNotEmpty) {
        // Only the selected three kinds, READ only. No sensor, write, history or
        // background permissions. The OS dialog waits for the user's decision.
        final completed = await _health.requestAuthorization(
          missing.map((metric) => _types[metric]!).toList(),
          permissions: [for (final _ in missing) HealthDataAccess.READ],
        );
        if (_platform == TargetPlatform.iOS) {
          if (!completed) {
            throw const HealthReadException(
              'Apple Sağlık izin isteği tamamlanamadı. Tekrar deneyin.',
            );
          }
          _iosPrompted.addAll(
            missing,
          ); // Prompt completed does NOT mean read permission granted.
        }
      }
    }
    final readings = <HealthMetric, HealthMetricReading>{};
    for (final metric in selected) {
      if (!supported.contains(metric)) {
        readings[metric] = const HealthMetricReading(
          HealthReadStatus.unsupported,
        );
        continue;
      }
      try {
        final allowed = _platform == TargetPlatform.iOS
            ? _iosPrompted.contains(metric)
            : await _allowed(metric);
        if (!allowed) {
          readings[metric] = HealthMetricReading(
            _platform == TargetPlatform.iOS
                ? HealthReadStatus.notRequested
                : HealthReadStatus.permissionRequired,
          );
          continue;
        }
        readings[metric] = await _readMetric(metric, day, at).timeout(_timeout);
        // Permission may have been revoked while the read was in progress.
        if (_platform == TargetPlatform.android && !await _allowed(metric)) {
          readings[metric] = const HealthMetricReading(
            HealthReadStatus.permissionRequired,
          );
        }
      } on Object {
        readings[metric] = const HealthMetricReading(HealthReadStatus.failed);
      }
    }
    return HealthSnapshot(
      availability: availability,
      platform: platformName,
      day: day,
      readAt: DateTime.now(),
      readings: Map.unmodifiable(readings),
    );
  }

  Future<bool> _allowed(HealthMetric metric) async =>
      await _health
          .hasPermissions(
            [_types[metric]!],
            permissions: [HealthDataAccess.READ],
          )
          .timeout(_timeout) ==
      true;

  Future<HealthMetricReading> _readMetric(
    HealthMetric metric,
    DateTime from,
    DateTime to,
  ) async {
    final type = _types[metric]!;
    final queryFrom = metric == HealthMetric.heartRate
        ? DateTime(from.year, from.month, from.day - 6)
        : from;
    final samples =
        _health
            .removeDuplicates(
              await _health.getHealthDataFromTypes(
                startTime: queryFrom,
                endTime: to,
                types: [type],
              ),
            )
            .where(
              (sample) =>
                  sample.value is NumericHealthValue &&
                  (sample.value as NumericHealthValue).numericValue.isFinite &&
                  (sample.value as NumericHealthValue).numericValue >= 0 &&
                  !sample.dateTo.isAfter(to) &&
                  !sample.dateTo.isBefore(queryFrom) &&
                  (metric != HealthMetric.heartRate ||
                      (sample.value as NumericHealthValue).numericValue > 0),
            )
            .toList()
          ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (samples.isEmpty) {
      // iOS deliberately hides read denial. Empty data cannot prove permission.
      return HealthMetricReading(
        _platform == TargetPlatform.iOS
            ? HealthReadStatus.permissionUnknown
            : HealthReadStatus.noData,
      );
    }
    double? value;
    if (metric == HealthMetric.steps) {
      value = (await _health.getTotalStepsInInterval(from, to))?.toDouble();
    } else if (metric == HealthMetric.activeCalories) {
      // Native statistics handle multiple sources; do not sum raw overlapping records.
      final totals = await _health.getHealthIntervalDataFromTypes(
        startDate: from,
        endDate: to,
        types: [type],
        interval: math.max(1, to.difference(from).inSeconds + 1),
      );
      if (totals.isNotEmpty &&
          totals.every((point) => point.value is NumericHealthValue)) {
        value = totals.fold<double>(
          0,
          (sum, point) =>
              sum + (point.value as NumericHealthValue).numericValue,
        );
      }
    } else {
      value = (samples.first.value as NumericHealthValue).numericValue
          .toDouble();
    }
    if (value == null || !value.isFinite || value < 0) {
      return const HealthMetricReading(HealthReadStatus.failed);
    }
    return HealthMetricReading(
      HealthReadStatus.data,
      value: value,
      recordedAt: samples.first.dateTo.toLocal(),
      sources: List.unmodifiable(
        (metric == HealthMetric.heartRate ? samples.take(1) : samples)
            .map((point) => point.sourceName.trim())
            .where((name) => name.isNotEmpty)
            .toSet(),
      ),
    );
  }

  Future<void> installHealthConnect() =>
      _health.installHealthConnect().timeout(_timeout);
  Future<void> openSettings() => const MethodChannel(
    'smart_health_fitness/health',
  ).invokeMethod<void>('openHealthSettings').timeout(_timeout);
}
