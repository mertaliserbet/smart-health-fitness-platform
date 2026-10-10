class WeightRecord {
  const WeightRecord({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
  });
  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
    id: json['id'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
  );
  final String id;
  final double weightKg;
  final DateTime recordedAt;
}

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.values,
    required this.recordedAt,
  });
  factory BodyMeasurement.fromJson(Map<String, dynamic> json) =>
      BodyMeasurement(
        id: json['id'] as String,
        values: Map.unmodifiable({
          for (final key in measurementLabels.keys)
            key: (json[key] as num?)?.toDouble(),
        }),
        recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
      );
  final String id;
  final Map<String, double?> values;
  final DateTime recordedAt;
}

const measurementLabels = {
  'chestCm': 'Göğüs',
  'waistCm': 'Bel',
  'hipCm': 'Kalça',
  'armCm': 'Kol',
  'thighCm': 'Uyluk',
  'bodyFatPercentage': 'Vücut yağ oranı',
};

String trackingNumber(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');

String trackingDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
