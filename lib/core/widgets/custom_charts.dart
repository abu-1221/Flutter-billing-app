import 'dart:math';
import 'package:flutter/material.dart';

// --- PIE CHART DATA MODEL ---
class PieChartSegment {
  final String label;
  final double value;
  final Color color;

  PieChartSegment({required this.label, required this.value, required this.color});
}

// --- CUSTOM PIE CHART WIDGET ---
class CustomPieChart extends StatelessWidget {
  final List<PieChartSegment> segments;

  const CustomPieChart({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final double total = segments.fold(0, (sum, item) => sum + item.value);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            size: const Size(180, 180),
            painter: _PieChartPainter(segments: segments, total: total),
          ),
        ),
        const SizedBox(height: 16),
        // Legends
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: segments.map((seg) {
            final double percent = total > 0 ? (seg.value / total) * 100 : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${seg.label} (${percent.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PieChartSegment> segments;
  final double total;

  _PieChartPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32;

    final double radius = (min(size.width, size.height) - paint.strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2; // start at top

    for (var seg in segments) {
      final sweepAngle = (seg.value / total) * 2 * pi;
      paint.color = seg.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- CUSTOM BAR CHART WIDGET ---
class CustomBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color barColor;

  const CustomBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.barColor = Colors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarChartPainter(values: values, labels: labels, barColor: barColor),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;

  _BarChartPainter({required this.values, required this.labels, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce(max);
    final double graphMax = maxVal == 0 ? 10.0 : maxVal * 1.2;

    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines
    const int gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = size.height - 24 - (i * (size.height - 40) / gridCount);
      canvas.drawLine(Offset(40, y), Offset(size.width - 16, y), gridPaint);

      // Draw grid labels
      final double val = (i * graphMax) / gridCount;
      textPainter.text = TextSpan(
        text: '₹${val.toStringAsFixed(0)}',
        style: TextStyle(color: Colors.grey[500], fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - (textPainter.height / 2)));
    }

    final int barCount = values.length;
    final double availWidth = size.width - 56;
    final double barSpacing = availWidth / barCount;
    final double barWidth = barSpacing * 0.5;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double val = values[i];
      final double barHeight = (val / graphMax) * (size.height - 40);
      final double x = 48 + (i * barSpacing) + (barSpacing - barWidth) / 2;
      final double y = size.height - 24 - barHeight;

      // Draw rounded rectangle bar
      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rRect, barPaint);

      // Draw labels under bars
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x + (barWidth - textPainter.width) / 2, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- CUSTOM LINE CHART WIDGET ---
class CustomLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  const CustomLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.lineColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(values: values, labels: labels, lineColor: lineColor),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  _LineChartPainter({required this.values, required this.labels, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce(max);
    final double graphMax = maxVal == 0 ? 10.0 : maxVal * 1.2;

    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines
    const int gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = size.height - 24 - (i * (size.height - 40) / gridCount);
      canvas.drawLine(Offset(40, y), Offset(size.width - 16, y), gridPaint);

      // Draw grid labels
      final double val = (i * graphMax) / gridCount;
      textPainter.text = TextSpan(
        text: '₹${val.toStringAsFixed(0)}',
        style: TextStyle(color: Colors.grey[500], fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - (textPainter.height / 2)));
    }

    final int pointCount = values.length;
    final double availWidth = size.width - 56;
    final double stepX = availWidth / (pointCount - 1);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < pointCount; i++) {
      final double val = values[i];
      final double y = size.height - 24 - ((val / graphMax) * (size.height - 40));
      final double x = 48 + (i * stepX);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 24);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == pointCount - 1) {
        fillPath.lineTo(x, size.height - 24);
        fillPath.close();
      }
    }

    // Draw filled path under line
    canvas.drawPath(fillPath, fillPaint);
    // Draw line
    canvas.drawPath(path, linePaint);

    // Draw dots and labels
    for (int i = 0; i < pointCount; i++) {
      final double val = values[i];
      final double y = size.height - 24 - ((val / graphMax) * (size.height - 40));
      final double x = 48 + (i * stepX);

      canvas.drawCircle(Offset(x, y), 5, dotPaint);

      // Draw label under dot
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - (textPainter.width / 2), size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
