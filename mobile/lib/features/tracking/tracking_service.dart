import '../../core/api_service.dart';
import 'tracking_models.dart';

class TrackingService {
  const TrackingService(this.api);
  final ApiService api;

  Future<List<WeightRecord>> getWeightRecords() async {
    final json = await api.getList('/api/users/me/weight-records');
    try {
      return json
          .map((item) => WeightRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      throw const ApiException('Kilo kayıtları okunamadı. Tekrar deneyin.');
    }
  }

  Future<List<BodyMeasurement>> getBodyMeasurements() async {
    final json = await api.getList('/api/users/me/body-measurements');
    try {
      return json
          .map((item) => BodyMeasurement.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      throw const ApiException('Ölçüm kayıtları okunamadı. Tekrar deneyin.');
    }
  }

  Future<void> createWeightRecord(double weightKg, DateTime recordedAt) async =>
      await api.post('/api/users/me/weight-records', {
        'weightKg': weightKg,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      }, authenticated: true);

  Future<void> createBodyMeasurement(
    Map<String, double?> values,
    DateTime recordedAt,
  ) async => await api.post('/api/users/me/body-measurements', {
    ...values,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  }, authenticated: true);
}
