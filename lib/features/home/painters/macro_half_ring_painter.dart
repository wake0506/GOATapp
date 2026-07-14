import 'dart:math' as math;

import 'package:flutter/material.dart';

class MacroHalfRingPainter extends CustomPainter {
  const MacroHalfRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(5, 5, size.width - 10, (size.width - 10) / 2);
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.1415926, 3.1415926, false, backgroundPaint);

    if (progress <= 0) return;
    final activeSweep = 3.1415926 * progress.clamp(0, 1);
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.1415926, activeSweep, false, activePaint);

    final angle = 3.1415926 + activeSweep;
    final center = rect.center;
    final radiusX = rect.width / 2;
    final radiusY = rect.height;
    final point = Offset(
      center.dx + radiusX * math.cos(angle),
      center.dy + radiusY * math.sin(angle),
    );
    canvas.drawCircle(point, 5, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawCircle(point, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant MacroHalfRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
