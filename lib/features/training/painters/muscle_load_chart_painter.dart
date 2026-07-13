import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';

class MuscleLoadChartPainter extends CustomPainter {
  final List<MuscleLoad> loads;

  const MuscleLoadChartPainter(this.loads);

  @override
  void paint(Canvas canvas, Size size) {
    const rowHeight = 31.0;
    const barStart = 112.0;
    const valueWidth = 34.0;
    final barWidth = (size.width - barStart - valueWidth)
        .clamp(48.0, size.width)
        .toDouble();
    final barPaint = Paint()..color = const Color(0xFFF0F2F3);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var index = 0; index < loads.length; index++) {
      final load = loads[index];
      final top = index * rowHeight;
      _drawText(
        canvas,
        textPainter,
        load.label,
        const TextStyle(
          color: Color(0xFF2D3135),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        Offset.zero.translate(0, top + 5),
      );
      _drawText(
        canvas,
        textPainter,
        load.englishLabel,
        const TextStyle(color: Color(0xFF8A9197), fontSize: 10),
        Offset.zero.translate(43, top + 7),
      );

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barStart, top + 7, barWidth, 15),
        const Radius.circular(12),
      );
      canvas.drawRRect(barRect, barPaint);
      if (load.value > 0) {
        final fillWidth = (barWidth * load.value / 100)
            .clamp(12.0, barWidth)
            .toDouble();
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barStart, top + 7, fillWidth, 15),
          const Radius.circular(12),
        );
        final fillPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF005A45), Color(0xFF5D9788)],
          ).createShader(fillRect.outerRect);
        canvas.drawRRect(fillRect, fillPaint);
      }
      _drawText(
        canvas,
        textPainter,
        '${load.value.round()}%',
        const TextStyle(
          color: Color(0xFF4A4F55),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        Offset.zero.translate(barStart + barWidth + 7, top + 8),
      );
    }
  }

  void _drawText(
    Canvas canvas,
    TextPainter painter,
    String value,
    TextStyle style,
    Offset offset,
  ) {
    painter.text = TextSpan(text: value, style: style);
    painter.layout(maxWidth: 105);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MuscleLoadChartPainter oldDelegate) =>
      oldDelegate.loads != loads;
}
