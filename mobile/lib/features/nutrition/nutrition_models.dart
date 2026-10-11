import '../assignments/assignment_models.dart';

const mealLabels = {
  'Breakfast': 'Kahvaltı',
  'Lunch': 'Öğle yemeği',
  'Dinner': 'Akşam yemeği',
  'Snack': 'Ara öğün',
};
const nutrientLabels = {
  'calories': 'Kalori (kcal)',
  'proteinGrams': 'Protein (g)',
  'carbohydrateGrams': 'Karbonhidrat (g)',
  'fatGrams': 'Yağ (g)',
};

const _summaryKeys = {
  'calories': 'consumedCalories',
  'proteinGrams': 'consumedProteinGrams',
  'carbohydrateGrams': 'consumedCarbohydrateGrams',
  'fatGrams': 'consumedFatGrams',
};

Map<String, double> _values(Map<String, dynamic> json, {bool summary = false}) {
  final values = {
    for (final key in nutrientLabels.keys)
      key: (json[summary ? _summaryKeys[key] : key] as num).toDouble(),
  };
  if (values.values.any((value) => !value.isFinite || value < 0)) {
    throw const FormatException('Invalid nutrition values');
  }
  return values;
}

class NutritionRecord {
  NutritionRecord.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      mealType = json['mealType'] as String,
      portionDescription = json['portionDescription'] as String?,
      consumedAt = DateTime.parse(json['consumedAt'] as String).toLocal(),
      values = _values(json) {
    if (!mealLabels.containsKey(mealType)) {
      throw const FormatException('Unknown meal type');
    }
  }
  final String id, name, mealType;
  final String? portionDescription;
  final DateTime consumedAt;
  final Map<String, double> values;
}

class NutritionDailySummary {
  NutritionDailySummary.fromJson(Map<String, dynamic> json)
    : date = json['date'] as String,
      recordCount = json['recordCount'] as int,
      values = _values(json, summary: true),
      goal = json['goal'] == null
          ? null
          : NutritionGoal.fromJson(json['goal'] as Map<String, dynamic>) {
    validateDate(date);
    if (recordCount < 0) throw const FormatException('Invalid record count');
  }
  final String date;
  final int recordCount;
  final Map<String, double> values;
  final NutritionGoal? goal;
}
