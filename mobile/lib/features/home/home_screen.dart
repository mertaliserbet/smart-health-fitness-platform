import 'package:flutter/material.dart';

import '../auth/user.dart';
import 'dashboard_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenPlan,
    required this.onOpenTracking,
    required this.onOpenAdvisors,
  });

  final User user;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenTracking;
  final VoidCallback onOpenAdvisors;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      key: const PageStorageKey('home-dashboard'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _welcome(context),
              const SizedBox(height: 24),
              DashboardCard(
                title: 'Bugünkü antrenman',
                icon: Icons.fitness_center,
                featured: true,
                actionLabel: 'Planıma Git',
                onAction: onOpenPlan,
                child: _emptyMessage(
                  context,
                  'Henüz antrenman verisi yok',
                  'Bugünkü programın hazır olduğunda burada görünecek.',
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns =
                      constraints.maxWidth >= 760 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 24;
                  final width = twoColumns
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final card in [
                        _nutritionCard(context),
                        _activityCard(context),
                        _weightCard(context),
                        _advisorsCard(context),
                      ])
                        SizedBox(width: width, child: card),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${now.day} ${months[now.month - 1]} ${now.year}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Merhaba, ${user.firstName}',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bugünkü sağlık ve fitness özetin.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _nutritionCard(BuildContext context) => DashboardCard(
    title: 'Kalori / makro özeti',
    icon: Icons.restaurant_outlined,
    actionLabel: 'Beslenme Planıma Git',
    onAction: onOpenPlan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _emptyMessage(
          context,
          'Henüz beslenme verisi yok',
          'Kalori ve makro hedeflerin ile günlük tüketimin burada görünecek.',
        ),
        const SizedBox(height: 16),
        _metrics(context, const [
          DashboardMetric(label: 'Kalori', unit: 'kcal'),
          DashboardMetric(label: 'Protein', unit: 'g'),
          DashboardMetric(label: 'Karbonhidrat', unit: 'g'),
          DashboardMetric(label: 'Yağ', unit: 'g'),
        ]),
      ],
    ),
  );

  Widget _activityCard(BuildContext context) => DashboardCard(
    title: 'Günlük aktivite',
    icon: Icons.directions_walk,
    actionLabel: 'Aktivite için Takibe Git',
    onAction: onOpenTracking,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _emptyMessage(
          context,
          'Henüz aktivite verisi yok',
          'Günlük adım ve aktivite özetin burada görünecek.',
        ),
        const SizedBox(height: 16),
        _metrics(context, const [
          DashboardMetric(label: 'Adım', unit: 'adım'),
          DashboardMetric(label: 'Aktif kalori', unit: 'kcal'),
        ]),
      ],
    ),
  );

  Widget _weightCard(BuildContext context) => DashboardCard(
    title: 'Kilo gelişimi',
    icon: Icons.monitor_weight_outlined,
    actionLabel: 'Kilo için Takibe Git',
    onAction: onOpenTracking,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardMetric(label: 'Son kilo', unit: 'kg'),
        const SizedBox(height: 16),
        _emptyMessage(
          context,
          'Henüz kilo verisi yok',
          'Gelişimini görmek için tarihli kilo verileri gerekiyor.',
        ),
      ],
    ),
  );

  Widget _advisorsCard(BuildContext context) => DashboardCard(
    title: 'Koç / diyetisyen',
    icon: Icons.people_outline,
    actionLabel: 'Rehberime Git',
    onAction: onOpenAdvisors,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _emptyMessage(context, 'Koç (antrenör)', 'Henüz koç bilgisi yok.'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        _emptyMessage(context, 'Diyetisyen', 'Henüz diyetisyen bilgisi yok.'),
      ],
    ),
  );

  Widget _emptyMessage(BuildContext context, String title, String message) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );

  Widget _metrics(BuildContext context, List<Widget> metrics) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      final width = twoColumns
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final metric in metrics) SizedBox(width: width, child: metric),
        ],
      );
    },
  );
}
