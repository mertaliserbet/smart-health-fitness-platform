import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../assignments/assignment_models.dart';
import '../assignments/assignment_service.dart';
import '../assignments/assignment_widgets.dart';
import 'user_task_card.dart';

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key, required this.api, required this.active});
  final ApiService api;
  final bool active;
  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  int _tab = 0;
  int _taskRevision = 0;
  static const _labels = ['Antrenman', 'Beslenme', 'Görevler'];
  AssignmentService get _service => AssignmentService(widget.api);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _labels.length; i++)
              ChoiceChip(
                label: Text(_labels[i]),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
          ],
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _tab,
          children: [
            AssignmentPage(
              storageKey: 'my-workout-plans',
              children: [
                AssignmentSection<List<WorkoutPlan>>(
                  title: 'Atanmış antrenman programları',
                  active: widget.active && _tab == 0,
                  load: _service.getWorkoutPlans,
                  builder: (plans) => Column(
                    children: [
                      if (plans.isEmpty)
                        const AssignmentCard(
                          children: [
                            Text('Henüz antrenman programı atanmadı.'),
                          ],
                        ),
                      for (final plan in plans)
                        AssignmentCard(
                          children: [
                            Text(
                              plan.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              plan.isActive
                                  ? 'Aktif program'
                                  : 'Geçmiş program',
                            ),
                            Text(
                              assignmentPeriod(plan.startDate, plan.endDate),
                            ),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutPlanDetailScreen(
                                    service: _service,
                                    planId: plan.id,
                                  ),
                                ),
                              ),
                              child: const Text('Programı Gör'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            AssignmentPage(
              storageKey: 'my-nutrition-goal',
              children: [
                AssignmentSection<NutritionGoal?>(
                  title: 'Aktif beslenme hedefi',
                  active: widget.active && _tab == 1,
                  load: _service.getActiveNutritionGoal,
                  builder: (goal) => goal == null
                      ? const AssignmentCard(
                          children: [
                            Text('Bugün için aktif beslenme hedefi yok.'),
                          ],
                        )
                      : AssignmentCard(
                          children: [
                            Text(
                              assignmentPeriod(goal.startDate, goal.endDate),
                            ),
                            for (final target in goal.targets.entries)
                              Text(
                                '${nutritionLabels[target.key]}: ${target.value.toStringAsFixed(target.value % 1 == 0 ? 0 : 2)}',
                              ),
                          ],
                        ),
                ),
              ],
            ),
            AssignmentPage(
              storageKey: 'my-tasks-notes',
              children: [
                AssignmentSection<List<UserTask>>(
                  key: ValueKey(_taskRevision),
                  title: 'Görevlerim',
                  active: widget.active && _tab == 2,
                  load: _service.getTasks,
                  builder: (tasks) => Column(
                    children: [
                      if (tasks.isEmpty)
                        const AssignmentCard(
                          children: [Text('Henüz görev atanmadı.')],
                        ),
                      for (final task in tasks)
                        UserTaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          service: _service,
                          onCompleted: (_) {
                            if (!mounted) return;
                            // Reload the canonical list; discard any older in-flight refresh.
                            setState(() => _taskRevision++);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AssignmentSection<List<AdvisorNote>>(
                  title: 'Danışman notları',
                  active: widget.active && _tab == 2,
                  load: _service.getNotes,
                  builder: (notes) => Column(
                    children: [
                      if (notes.isEmpty)
                        const AssignmentCard(
                          children: [Text('Henüz danışman notu yok.')],
                        ),
                      for (final note in notes)
                        AssignmentCard(
                          children: [
                            Text(
                              note.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(note.content),
                            Text(
                              assignmentDate(note.createdAt.toIso8601String()),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class WorkoutPlanDetailScreen extends StatelessWidget {
  const WorkoutPlanDetailScreen({
    super.key,
    required this.service,
    required this.planId,
  });
  final AssignmentService service;
  final String planId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Antrenman programı')),
    body: AssignmentPage(
      storageKey: 'workout-plan-$planId',
      children: [
        AssignmentSection<WorkoutPlan>(
          title: 'Program detayları',
          active: true,
          load: () => service.getWorkoutPlan(planId),
          builder: (plan) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(plan.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(assignmentPeriod(plan.startDate, plan.endDate)),
              if (plan.description?.isNotEmpty == true) Text(plan.description!),
              const SizedBox(height: 16),
              if (plan.days.isEmpty)
                const Text('Programda henüz antrenman günü yok.'),
              for (final day in plan.days)
                AssignmentCard(
                  children: [
                    Text(
                      '${weekdayLabels[day.weekday]} • ${day.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (day.description?.isNotEmpty == true)
                      Text(day.description!),
                    if (day.exercises.isEmpty)
                      const Text('Bu gün için egzersiz eklenmedi.'),
                    for (final exercise in day.exercises) ...[
                      const Divider(),
                      Text(
                        exercise.exerciseName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (exercise.sets != null) Text('Set: ${exercise.sets}'),
                      if (exercise.reps != null)
                        Text('Tekrar: ${exercise.reps}'),
                      if (exercise.durationSeconds != null)
                        Text('Süre: ${exercise.durationSeconds} sn'),
                      if (exercise.restSeconds != null)
                        Text('Dinlenme: ${exercise.restSeconds} sn'),
                      if (exercise.weightKg != null)
                        Text('Ağırlık: ${exercise.weightKg} kg'),
                      if (exercise.notes?.isNotEmpty == true)
                        Text(exercise.notes!),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
