import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../assignments/assignment_models.dart';
import '../assignments/assignment_service.dart';
import '../assignments/assignment_widgets.dart';

class MyAdvisorsScreen extends StatelessWidget {
  const MyAdvisorsScreen({super.key, required this.api, required this.active});
  final ApiService api;
  final bool active;
  @override
  Widget build(BuildContext context) => AssignmentPage(
    storageKey: 'my-advisors',
    children: [
      AssignmentSection<List<UserAdvisor>>(
        title: 'Koç ve diyetisyenlerim',
        active: active,
        load: AssignmentService(api).getAdvisors,
        builder: (advisors) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final type in ['Trainer', 'Dietitian']) ...[
              const SizedBox(height: 16),
              Text(
                type == 'Trainer' ? 'Koçum' : 'Diyetisyenim',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!advisors.any((advisor) => advisor.advisorType == type))
                AssignmentCard(
                  children: [
                    Text(
                      type == 'Trainer'
                          ? 'Henüz koç atanmadı.'
                          : 'Henüz diyetisyen atanmadı.',
                    ),
                  ],
                ),
              for (final advisor in advisors.where(
                (item) => item.advisorType == type,
              ))
                AssignmentCard(
                  children: [
                    Text(
                      advisor.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      type == 'Trainer'
                          ? 'Koç • Trainer'
                          : 'Diyetisyen • Dietitian',
                    ),
                    if (advisor.title?.isNotEmpty == true) Text(advisor.title!),
                    if (advisor.specialization?.isNotEmpty == true)
                      Text('Uzmanlık: ${advisor.specialization!}'),
                    Text('Atama tarihi: ${assignmentDate(advisor.startDate)}'),
                  ],
                ),
            ],
          ],
        ),
      ),
    ],
  );
}
