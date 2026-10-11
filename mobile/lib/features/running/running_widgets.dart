import 'dart:math';

import 'package:flutter/material.dart';

import '../tracking/tracking_models.dart' show trackingNumber;
import 'running_models.dart';

class RunningStats extends StatelessWidget {
  const RunningStats({
    super.key,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.pace,
    required this.speed,
  });
  final int durationSeconds;
  final double distanceMeters, speed;
  final double? pace;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (final metric in {
            'Aktif süre': runningDuration(durationSeconds),
            'Mesafe': '${trackingNumber(distanceMeters / 1000)} km',
            'Ortalama pace': runningPace(pace),
            'Ortalama hız': '${trackingNumber(speed)} km/sa',
          }.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.key, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class RunningRouteView extends StatelessWidget {
  const RunningRouteView({super.key, required this.segments});
  final List<List<RunningPoint>> segments;
  @override
  Widget build(BuildContext context) {
    final count = segments.fold<int>(
      0,
      (total, segment) => total + segment.length,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'GPS rotası • $count nokta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (count == 0)
              const Text('Henüz GPS noktası yok.')
            else
              SizedBox(
                height: 220,
                child: Semantics(
                  label:
                      'Kaydedilen GPS rotası. Duraklama aralıkları birbirine bağlanmaz.',
                  child: CustomPaint(
                    painter: _RoutePainter(
                      segments,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.segments, this.color);
  final List<List<RunningPoint>> segments;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final all = segments.expand((segment) => segment).toList();
    if (all.isEmpty) return;
    final origin = all.first;
    Offset project(RunningPoint point) {
      final lon = (point.longitude - origin.longitude + 540) % 360 - 180;
      return Offset(
        lon * cos(origin.latitude * pi / 180),
        -(point.latitude - origin.latitude),
      );
    }

    final projected = all.map(project).toList();
    final left = projected.map((p) => p.dx).reduce(min),
        right = projected.map((p) => p.dx).reduce(max);
    final top = projected.map((p) => p.dy).reduce(min),
        bottom = projected.map((p) => p.dy).reduce(max);
    final scale = min(
      (size.width - 32) / max(right - left, 0.000001),
      (size.height - 32) / max(bottom - top, 0.000001),
    );
    Offset screen(RunningPoint point) =>
        (project(point) - Offset((left + right) / 2, (top + bottom) / 2)) *
            scale +
        Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final segment in segments) {
      if (segment.isEmpty) continue;
      final path = Path()
        ..moveTo(screen(segment.first).dx, screen(segment.first).dy);
      for (final point in segment.skip(1)) {
        final offset = screen(point);
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, paint);
      canvas.drawCircle(screen(segment.first), 4, Paint()..color = color);
      canvas.drawCircle(screen(segment.last), 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      segments != oldDelegate.segments || color != oldDelegate.color;
}
