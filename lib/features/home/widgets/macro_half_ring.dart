import 'package:flutter/material.dart';

import '../painters/macro_half_ring_painter.dart';

class MacroHalfRing extends StatelessWidget {
  const MacroHalfRing({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  final String label;
  final double current;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double progress = target <= 0
        ? 0
        : (current / target).clamp(0, 1).toDouble();
    return Semantics(
      label: '$label ${current.toInt()} 克，目标 ${target.toInt()} 克',
      child: SizedBox(
        height: 107,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              width: 94,
              height: 56,
              child: CustomPaint(
                painter: MacroHalfRingPainter(progress: progress, color: color),
              ),
            ),
            Positioned(
              top: 34,
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF3B4645),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    current.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF1F2725),
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    target <= 0 ? '/ -- g' : '/${target.toInt()}g',
                    style: const TextStyle(
                      color: Color(0xFF78807F),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
