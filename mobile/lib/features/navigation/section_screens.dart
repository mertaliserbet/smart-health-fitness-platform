import 'package:flutter/material.dart';
import 'section_placeholder.dart';

class AIScreen extends StatelessWidget {
  const AIScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'AI',
    icon: Icons.auto_awesome_outlined,
    description: 'Yemek ve spor ekipmanı analizlerine buradan ulaşabileceksin.',
  );
}
