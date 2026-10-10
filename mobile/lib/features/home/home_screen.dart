import 'package:flutter/material.dart';

import '../auth/user.dart';
import '../navigation/section_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) => SectionPlaceholder(
    title: 'Merhaba, ${user.firstName}',
    icon: Icons.home_outlined,
    description: 'Günlük sağlık ve fitness özetin burada yer alacak.',
  );
}
