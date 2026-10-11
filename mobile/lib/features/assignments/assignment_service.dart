import '../../core/api_service.dart';
import 'assignment_models.dart';

class AssignmentService {
  const AssignmentService(this.api);
  final ApiService api;

  Future<UserTask> completeTask(String id) async {
    final task = UserTask.fromJson(
      await api.patch('/api/tasks/${Uri.encodeComponent(id)}', {
        'status': 'Completed',
      }),
    );
    if (task.id != id || task.status != 'Completed') {
      throw const ApiException(
        'Görev tamamlama yanıtı doğrulanamadı. Listeyi yenileyin.',
      );
    }
    return task;
  }

  Future<List<WorkoutPlan>> getWorkoutPlans() async => (await api.getList(
    '/api/users/me/workout-plans',
  )).map((item) => WorkoutPlan.fromJson(item as Map<String, dynamic>)).toList();

  Future<WorkoutPlan> getWorkoutPlan(String id) async {
    final plan = WorkoutPlan.fromJson(
      await api.get('/api/workout-plans/${Uri.encodeComponent(id)}'),
      detail: true,
    );
    plan.days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return plan;
  }

  Future<NutritionGoal?> getActiveNutritionGoal() async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final goal = NutritionGoal.fromJson(
        await api.get('/api/users/me/nutrition-goals/active?date=$date'),
      );
      // Never show an inactive or out-of-range target as today's target.
      if (!goal.isActive ||
          goal.startDate.compareTo(date) > 0 ||
          (goal.endDate != null && goal.endDate!.compareTo(date) < 0)) {
        throw const ApiException('Sunucu geçerli bir aktif hedef döndürmedi.');
      }
      return goal;
    } on ApiException catch (error) {
      // A missing route also returns 404; only the documented domain error
      // means that this user has no target. Do not hide unimplemented services.
      if (error.statusCode == 404 && error.code == 'NutritionGoalNotFound') {
        return null;
      }
      rethrow;
    }
  }

  Future<List<UserAdvisor>> getAdvisors() async => (await api.getList(
    '/api/users/me/advisors',
  )).map((item) => UserAdvisor.fromJson(item as Map<String, dynamic>)).toList();

  Future<List<UserTask>> getTasks() async => (await api.getList(
    '/api/users/me/tasks',
  )).map((item) => UserTask.fromJson(item as Map<String, dynamic>)).toList();

  Future<List<AdvisorNote>> getNotes() async {
    final notes = (await api.getList('/api/users/me/advisor-notes'))
        .map((item) => AdvisorNote.fromJson(item as Map<String, dynamic>))
        .toList();
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }
}
