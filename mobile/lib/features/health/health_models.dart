enum HealthMetric {
  steps('Adım', 'adım'),
  activeCalories('Aktif kalori', 'kcal'),
  heartRate('Kalp atış hızı', 'bpm');

  const HealthMetric(this.label, this.unit);
  final String label, unit;
}

enum HealthAvailability { available, unsupported, installRequired }

enum HealthReadStatus {
  notRequested,
  data,
  permissionRequired,
  noData,
  permissionUnknown,
  unsupported,
  failed,
}

class HealthMetricReading {
  const HealthMetricReading(
    this.status, {
    this.value,
    this.recordedAt,
    this.sources = const [],
  });
  final HealthReadStatus status;
  final double? value;
  final DateTime? recordedAt;
  final List<String> sources;
}

/// Screen-only snapshot of the device store; not a backend entity or a synced record.
class HealthSnapshot {
  const HealthSnapshot({
    required this.availability,
    required this.platform,
    required this.day,
    required this.readAt,
    required this.readings,
  });
  final HealthAvailability availability;
  final String platform;
  final DateTime day, readAt;
  final Map<HealthMetric, HealthMetricReading> readings;
}

class HealthReadException implements Exception {
  const HealthReadException(this.message);
  final String message;
}
