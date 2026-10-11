import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tracking_models.dart';
import 'tracking_progress.dart';

class TrackingSection extends StatelessWidget {
  const TrackingSection({
    super.key,
    required this.title,
    required this.loading,
    required this.error,
    required this.hasData,
    required this.retry,
    required this.children,
  });
  final String title;
  final bool loading, hasData;
  final String? error;
  final VoidCallback retry;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (loading) ...[
        const LinearProgressIndicator(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Kayıtlar yükleniyor…'),
        ),
      ],
      if (error != null) ...[
        TrackingCard(
          children: [
            Text(error!),
            if (hasData) const Text('Son yüklenen kayıtlar gösteriliyor.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: loading ? null : retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      ...children,
    ],
  );
}

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            children[index],
          ],
        ],
      ),
    ),
  );
}

class ProgressChart extends StatefulWidget {
  const ProgressChart({
    super.key,
    required this.points,
    required this.unit,
    required this.empty,
  });
  final List<ProgressPoint> points;
  final String unit, empty;
  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  int? _selected;
  @override
  void didUpdateWidget(covariant ProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return Text(widget.empty);
    if (points.length == 1) {
      return const Text(
        'Grafik için farklı zamanlarda en az iki kayıt gerekli.',
      );
    }
    final selected = points[_selected ?? points.length - 1];
    final values = points.map((point) => point.value);
    final min = values.reduce(math.min), max = values.reduce(math.max);
    final change = points.last.value - points.first.value;
    final changeUnit = widget.unit == '%' ? 'yüzde puan' : widget.unit;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Değişim: ${change > 0 ? '+' : ''}${trackingNumber(change)} $changeUnit',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          'Değer aralığı: ${trackingNumber(min)} – ${trackingNumber(max)} ${widget.unit}',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return Semantics(
              label:
                  '${points.length} gerçek kayıttan gelişim grafiği. Tarihli değerler kayıt geçmişinde de gösterilir.',
              child: GestureDetector(
                onTapDown: (tap) {
                  final fraction =
                      ((tap.localPosition.dx - 8) / (constraints.maxWidth - 16))
                          .clamp(0.0, 1.0);
                  final span = points.last.at
                      .difference(points.first.at)
                      .inMicroseconds;
                  final target =
                      points.first.at.microsecondsSinceEpoch + fraction * span;
                  var closest = 0;
                  for (var i = 1; i < points.length; i++) {
                    if ((points[i].at.microsecondsSinceEpoch - target).abs() <
                        (points[closest].at.microsecondsSinceEpoch - target)
                            .abs()) {
                      closest = i;
                    }
                  }
                  setState(() => _selected = closest);
                },
                child: CustomPaint(
                  key: const ValueKey('progress-plot'),
                  size: Size(constraints.maxWidth, 150),
                  painter: _ProgressPainter(
                    points,
                    theme.colorScheme.primary,
                    theme.colorScheme.outlineVariant,
                    _selected ?? points.length - 1,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          children: [
            Text(progressDay(points.first.at)),
            Text(progressDay(points.last.at)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${trackingDate(selected.at)} • ${trackingNumber(selected.value)} ${widget.unit}',
        ),
        const Text(
          'Noktalara dokunarak kayıtları görebilirsin. Kayıt olmayan günler doldurulmaz.',
        ),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.points, this.color, this.grid, this.selected);
  final List<ProgressPoint> points;
  final Color color, grid;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((point) => point.value);
    final min = values.reduce(math.min), max = values.reduce(math.max);
    final range = max - min;
    final span = points.last.at.difference(points.first.at).inMicroseconds;
    final plot = Rect.fromLTWH(
      8,
      10,
      math.max(1, size.width - 16),
      size.height - 20,
    );
    final locations = points
        .map(
          (point) => Offset(
            plot.left +
                point.at.difference(points.first.at).inMicroseconds /
                    span *
                    plot.width,
            range == 0
                ? plot.center.dy
                : plot.bottom - (point.value - min) / range * plot.height,
          ),
        )
        .toList();
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plot.top + plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    final line = Path()..moveTo(locations.first.dx, locations.first.dy);
    for (final point in locations.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(locations.last.dx, plot.bottom)
      ..lineTo(locations.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .25), color.withValues(alpha: .02)],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in locations) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
    canvas.drawCircle(locations[selected], 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      points != oldDelegate.points ||
      selected != oldDelegate.selected ||
      color != oldDelegate.color ||
      grid != oldDelegate.grid;
}
