import '../../core/api_service.dart';
import 'nutrition_models.dart';

class NutritionService {
  const NutritionService(this.api);
  final ApiService api;
  static const path = '/api/users/me/nutrition-records';

  Future<List<NutritionRecord>> getRecords() async {
    final json = await api.getList(path);
    try {
      return json
          .map((item) => NutritionRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      throw const ApiException('Beslenme kayıtları okunamadı. Tekrar deneyin.');
    }
  }

  Future<NutritionDailySummary> getDailySummary(DateTime day) async {
    // Construct consecutive calendar midnights: a local day may be 23 or 25 hours.
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    final uri = Uri(
      path: '$path/daily-summary',
      queryParameters: {
        'date': from.toIso8601String().substring(0, 10),
        'from': _withOffset(from),
        'to': _withOffset(to),
      },
    );
    final json = await api.get(uri.toString());
    try {
      return NutritionDailySummary.fromJson(json);
    } on Object {
      throw const ApiException(
        'Günlük beslenme özeti okunamadı. Tekrar deneyin.',
      );
    }
  }

  Future<void> createRecord({
    required String mealType,
    required String name,
    required Map<String, double> values,
    required DateTime consumedAt,
    String? portionDescription,
  }) async {
    await api.post(path, {
      'mealType': mealType,
      'name': name.trim(),
      ...values,
      'portionDescription': portionDescription?.trim(),
      'sourceType': 'Manual',
      'foodRecognitionLogId': null,
      'consumedAt': consumedAt.toUtc().toIso8601String(),
    }, authenticated: true);
  }

  String _withOffset(DateTime date) {
    final minutes = date.timeZoneOffset.inMinutes;
    final hours = (minutes.abs() ~/ 60).toString().padLeft(2, '0');
    final remainder = (minutes.abs() % 60).toString().padLeft(2, '0');
    return '${date.toIso8601String()}${minutes < 0 ? '-' : '+'}$hours:$remainder';
  }
}
