import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../assignments/assignment_models.dart';
import '../assignments/assignment_service.dart';
import '../assignments/assignment_widgets.dart';

class UserTaskCard extends StatefulWidget {
  const UserTaskCard({
    super.key,
    required this.task,
    required this.service,
    required this.onCompleted,
  });
  final UserTask task;
  final AssignmentService service;
  final ValueChanged<UserTask> onCompleted;

  @override
  State<UserTaskCard> createState() => _UserTaskCardState();
}

class _UserTaskCardState extends State<UserTaskCard> {
  bool _saving = false;
  String? _error;

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final task = await widget.service.completeTask(widget.task.id);
      if (mounted) widget.onCompleted(task);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Görev tamamlanamadı. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AssignmentCard(
    children: [
      Text(widget.task.title, style: Theme.of(context).textTheme.titleMedium),
      Text(taskStatusLabels[widget.task.status]!),
      if (widget.task.description?.isNotEmpty == true)
        Text(widget.task.description!),
      if (widget.task.dueDate != null)
        Text('Son tarih: ${assignmentDate(widget.task.dueDate!)}'),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (['Pending', 'InProgress'].contains(widget.task.status))
        FilledButton.icon(
          onPressed: _saving ? null : _complete,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'Kaydediliyor…' : 'Tamamlandı olarak işaretle'),
        ),
    ],
  );
}
