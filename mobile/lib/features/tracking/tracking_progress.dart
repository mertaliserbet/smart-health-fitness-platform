import '../running/running_models.dart';

enum TrackingPeriod {
  week('7 gün', 7),
  month('30 gün', 30),
  all('Tüm zamanlar', null);

  const TrackingPeriod(this.label, this.days);
  final String label;
  final int? days;

  // Calendar days, including today; do not subtract 24-hour durations across DST.
  bool contains(DateTime recordedAt, DateTime now) {
    final local = recordedAt.toLocal();
    final today = now.toLocal();
    final end = DateTime(today.year, today.month, today.day + 1);
    final start = days == null
        ? null
        : DateTime(today.year, today.month, today.day - days! + 1);
    return local.isBefore(end) && (start == null || !local.isBefore(start));
  }
}

typedef ProgressPoint = ({DateTime at, double value});

/// API lists newest first. Keep the first value at identical timestamps for the
/// chart; the history still shows every record. Missing values are never zeroes.
List<ProgressPoint> progressSeries(Iterable<ProgressPoint> records) {
  final unique = <int, ProgressPoint>{};
  for (final point in records) {
    unique.putIfAbsent(point.at.microsecondsSinceEpoch, () => point);
  }
  return unique.values.toList()..sort((a, b) => a.at.compareTo(b.at));
}

({int count, double distanceMeters, int durationSeconds}) runningTotals(
  Iterable<RunningActivity> records,
) => (
  count: records.length,
  distanceMeters: records.fold(0, (total, run) => total + run.distanceMeters),
  durationSeconds: records.fold(0, (total, run) => total + run.durationSeconds),
);

String progressDay(DateTime at) =>
    '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}.${at.year}';
