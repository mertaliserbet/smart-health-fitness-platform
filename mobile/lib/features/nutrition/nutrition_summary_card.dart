import 'package:flutter/material.dart';

import '../tracking/tracking_models.dart' show trackingNumber;
import 'nutrition_models.dart';

class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({super.key, required this.summary});
  final NutritionDailySummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${summary.recordCount} öğün kaydı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (summary.recordCount == 0)
            const Text('Bu gün için henüz beslenme kaydı yok.'),
          const SizedBox(height: 12),
          if (summary.goal == null)
            const Text(
              'Bu gün için geçerli aktif beslenme hedefin yok. Tüketim toplamların aşağıda.',
            ),
          for (final value in summary.values.entries)
            _metric(context, value.key, value.value),
        ],
      ),
    ),
  );

  Widget _metric(BuildContext context, String key, double consumed) {
    final target =
        summary.goal?.targets[key == 'calories' ? 'dailyCalories' : key];
    final difference = target == null ? null : target - consumed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nutrientLabels[key]!,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            target == null
                ? trackingNumber(consumed)
                : '${trackingNumber(consumed)} / ${trackingNumber(target)}',
          ),
          if (difference != null)
            Text(
              difference < 0
                  ? 'Hedefin üzerinde: ${trackingNumber(-difference)}'
                  : 'Kalan: ${trackingNumber(difference)}',
            ),
          if (target != null && target > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (consumed / target).clamp(0.0, 1.0)),
          ],
        ],
      ),
    );
  }
}
