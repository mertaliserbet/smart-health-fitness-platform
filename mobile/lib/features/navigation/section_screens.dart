import 'package:flutter/material.dart';
import 'section_placeholder.dart';

class MyPlanScreen extends StatelessWidget {
  const MyPlanScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'Planım',
    icon: Icons.assignment_outlined,
    description: 'Antrenman ve beslenme planların burada yer alacak.',
  );
}

class AIScreen extends StatelessWidget {
  const AIScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'AI',
    icon: Icons.auto_awesome_outlined,
    description: 'Yemek ve spor ekipmanı analizlerine buradan ulaşabileceksin.',
  );
}

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'Takip',
    icon: Icons.insights_outlined,
    description: 'Kilo, ölçüm ve aktivite geçmişin burada yer alacak.',
  );
}

class MyAdvisorsScreen extends StatelessWidget {
  const MyAdvisorsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'Rehberim',
    icon: Icons.people_outline,
    description: 'Antrenör ve diyetisyen bilgilerine buradan ulaşabileceksin.',
  );
}
