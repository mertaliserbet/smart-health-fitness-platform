class WorkoutPlan {
  WorkoutPlan.fromJson(Map<String, dynamic> json, {bool detail = false})
    : id = json['id'] as String,
      name = json['name'] as String,
      description = json['description'] as String?,
      isActive = json['isActive'] as bool,
      startDate = json['startDate'] as String,
      endDate = json['endDate'] as String?,
      days = detail
          ? (json['days'] as List)
                .map((day) => WorkoutDay.fromJson(day as Map<String, dynamic>))
                .toList()
          : [] {
    validatePeriod(startDate, endDate);
  }

  final String id, name, startDate;
  final String? description, endDate;
  final bool isActive;
  final List<WorkoutDay> days;
}

class WorkoutDay {
  WorkoutDay.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      weekday = json['weekday'] as String,
      dayNumber = json['dayNumber'] as int,
      description = json['description'] as String?,
      exercises = (json['exercises'] as List)
          .map((item) => WorkoutExercise.fromJson(item as Map<String, dynamic>))
          .toList() {
    if (!weekdayLabels.containsKey(weekday)) {
      throw const FormatException('Unknown weekday');
    }
    exercises.sort((a, b) => a.order.compareTo(b.order));
  }
  final String name, weekday;
  final String? description;
  final int dayNumber;
  final List<WorkoutExercise> exercises;
}

class WorkoutExercise {
  WorkoutExercise.fromJson(Map<String, dynamic> json)
    : exerciseName = json['exerciseName'] as String,
      order = json['order'] as int,
      sets = json['sets'] as int?,
      reps = json['reps'] as int?,
      durationSeconds = json['durationSeconds'] as int?,
      restSeconds = json['restSeconds'] as int?,
      weightKg = (json['weightKg'] as num?)?.toDouble(),
      notes = json['notes'] as String?;
  final String exerciseName;
  final int order;
  final int? sets, reps, durationSeconds, restSeconds;
  final double? weightKg;
  final String? notes;
}

class NutritionGoal {
  NutritionGoal.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      isActive = json['isActive'] as bool,
      startDate = json['startDate'] as String,
      endDate = json['endDate'] as String?,
      targets = {
        for (final key in nutritionLabels.keys)
          key: (json[key] as num).toDouble(),
      } {
    validatePeriod(startDate, endDate);
    if (targets.values.any((value) => !value.isFinite || value < 0)) {
      throw const FormatException('Invalid target');
    }
  }
  final String id, startDate;
  final String? endDate;
  final bool isActive;
  final Map<String, double> targets;
}

class UserAdvisor {
  UserAdvisor.fromJson(Map<String, dynamic> json)
    : userAdvisorId = json['userAdvisorId'] as String,
      advisorId = json['advisorId'] as String,
      advisorType = json['advisorType'] as String,
      firstName = json['firstName'] as String,
      lastName = json['lastName'] as String,
      title = json['title'] as String?,
      specialization = json['specialization'] as String?,
      startDate = json['startDate'] as String,
      status = json['status'] as String {
    validateDate(startDate);
    if (!['Trainer', 'Dietitian'].contains(advisorType) || status != 'Active') {
      throw const FormatException('Invalid active advisor');
    }
  }
  final String userAdvisorId, advisorId, advisorType;
  final String firstName, lastName, startDate, status;
  final String? title, specialization;
  String get fullName => '$firstName $lastName';
}

class UserTask {
  UserTask.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      advisorId = json['advisorId'] as String,
      title = json['title'] as String,
      description = json['description'] as String?,
      dueDate = json['dueDate'] as String?,
      status = json['status'] as String {
    if (dueDate != null) validateDate(dueDate!);
    if (!taskStatusLabels.containsKey(status)) {
      throw const FormatException('Unknown task status');
    }
  }
  final String id, advisorId, title, status;
  final String? description, dueDate;
}

class AdvisorNote {
  AdvisorNote.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      advisorId = json['advisorId'] as String,
      title = json['title'] as String,
      content = json['content'] as String,
      createdAt = DateTime.parse(json['createdAt'] as String).toLocal();
  final String id, advisorId, title, content;
  final DateTime createdAt;
}

const weekdayLabels = {
  'Monday': 'Pazartesi',
  'Tuesday': 'Salı',
  'Wednesday': 'Çarşamba',
  'Thursday': 'Perşembe',
  'Friday': 'Cuma',
  'Saturday': 'Cumartesi',
  'Sunday': 'Pazar',
};
const nutritionLabels = {
  'dailyCalories': 'Kalori hedefi (kcal)',
  'proteinGrams': 'Protein hedefi (g)',
  'carbohydrateGrams': 'Karbonhidrat hedefi (g)',
  'fatGrams': 'Yağ hedefi (g)',
  'waterMl': 'Su hedefi (ml)',
};
const taskStatusLabels = {
  'Pending': 'Bekliyor',
  'InProgress': 'Devam ediyor',
  'Completed': 'Tamamlandı',
  'Cancelled': 'İptal edildi',
};

String assignmentDate(String value) {
  final date = DateTime.parse(value);
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String assignmentPeriod(String start, String? end) =>
    '${assignmentDate(start)} – ${end == null ? 'Bitiş tarihi yok' : assignmentDate(end)}';

void validateDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Invalid calendar date');
  }
}

void validatePeriod(String start, String? end) {
  validateDate(start);
  if (end != null) {
    validateDate(end);
    if (end.compareTo(start) < 0) throw const FormatException('Invalid period');
  }
}
