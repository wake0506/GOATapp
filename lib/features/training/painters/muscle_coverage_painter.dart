import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/training_coverage.dart';

enum MuscleMapView { front, back }

class MuscleCoveragePainter extends CustomPainter {
  const MuscleCoveragePainter({required this.coverage, required this.view});

  final TrainingCoverageResult coverage;
  final MuscleMapView view;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 220;
    final scaleY = size.height / 360;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final outline = Paint()..color = const Color(0xFFE7EAE9);
    final stroke = Paint()
      ..color = const Color(0xFFCFD5D3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawOval(const Rect.fromLTWH(91, 8, 38, 44), outline);
    final torso = Path()
      ..moveTo(75, 58)
      ..quadraticBezierTo(110, 48, 145, 58)
      ..lineTo(154, 174)
      ..quadraticBezierTo(110, 194, 66, 174)
      ..close();
    canvas.drawPath(torso, outline);
    canvas.drawPath(torso, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 62, 27, 142),
        const Radius.circular(14),
      ),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(151, 62, 27, 142),
        const Radius.circular(14),
      ),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 176, 34, 174),
        const Radius.circular(16),
      ),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(114, 176, 34, 174),
        const Radius.circular(16),
      ),
      outline,
    );

    if (view == MuscleMapView.front) {
      _paintFront(canvas);
    } else {
      _paintBack(canvas);
    }
    canvas.restore();
  }

  void _paintFront(Canvas canvas) {
    _region(
      canvas,
      MuscleRegion.upperChest,
      const Rect.fromLTWH(78, 67, 30, 23),
    );
    _region(
      canvas,
      MuscleRegion.upperChest,
      const Rect.fromLTWH(112, 67, 30, 23),
    );
    _region(canvas, MuscleRegion.midChest, const Rect.fromLTWH(76, 88, 32, 29));
    _region(
      canvas,
      MuscleRegion.midChest,
      const Rect.fromLTWH(112, 88, 32, 29),
    );
    _region(
      canvas,
      MuscleRegion.lowerChest,
      const Rect.fromLTWH(80, 114, 28, 17),
    );
    _region(
      canvas,
      MuscleRegion.lowerChest,
      const Rect.fromLTWH(112, 114, 28, 17),
    );
    _region(
      canvas,
      MuscleRegion.frontDelts,
      const Rect.fromLTWH(61, 62, 22, 26),
    );
    _region(
      canvas,
      MuscleRegion.frontDelts,
      const Rect.fromLTWH(137, 62, 22, 26),
    );
    _region(
      canvas,
      MuscleRegion.sideDelts,
      const Rect.fromLTWH(51, 69, 17, 28),
    );
    _region(
      canvas,
      MuscleRegion.sideDelts,
      const Rect.fromLTWH(152, 69, 17, 28),
    );
    _region(canvas, MuscleRegion.biceps, const Rect.fromLTWH(48, 98, 19, 45));
    _region(canvas, MuscleRegion.biceps, const Rect.fromLTWH(153, 98, 19, 45));
    _region(
      canvas,
      MuscleRegion.forearms,
      const Rect.fromLTWH(46, 145, 18, 51),
    );
    _region(
      canvas,
      MuscleRegion.forearms,
      const Rect.fromLTWH(156, 145, 18, 51),
    );
    _region(canvas, MuscleRegion.abs, const Rect.fromLTWH(94, 132, 32, 55));
    _region(
      canvas,
      MuscleRegion.obliques,
      const Rect.fromLTWH(76, 132, 17, 49),
    );
    _region(
      canvas,
      MuscleRegion.obliques,
      const Rect.fromLTWH(127, 132, 17, 49),
    );
    _region(canvas, MuscleRegion.quads, const Rect.fromLTWH(75, 189, 29, 83));
    _region(canvas, MuscleRegion.quads, const Rect.fromLTWH(116, 189, 29, 83));
    _region(
      canvas,
      MuscleRegion.adductors,
      const Rect.fromLTWH(96, 190, 10, 70),
    );
    _region(
      canvas,
      MuscleRegion.adductors,
      const Rect.fromLTWH(114, 190, 10, 70),
    );
    _region(canvas, MuscleRegion.calves, const Rect.fromLTWH(78, 278, 25, 61));
    _region(canvas, MuscleRegion.calves, const Rect.fromLTWH(117, 278, 25, 61));
  }

  void _paintBack(Canvas canvas) {
    _region(
      canvas,
      MuscleRegion.rearDelts,
      const Rect.fromLTWH(53, 67, 28, 29),
    );
    _region(
      canvas,
      MuscleRegion.rearDelts,
      const Rect.fromLTWH(139, 67, 28, 29),
    );
    _region(
      canvas,
      MuscleRegion.upperBack,
      const Rect.fromLTWH(80, 65, 60, 30),
    );
    _region(canvas, MuscleRegion.lats, const Rect.fromLTWH(72, 91, 35, 57));
    _region(canvas, MuscleRegion.lats, const Rect.fromLTWH(113, 91, 35, 57));
    _region(canvas, MuscleRegion.midBack, const Rect.fromLTWH(96, 94, 28, 50));
    _region(
      canvas,
      MuscleRegion.lowerBack,
      const Rect.fromLTWH(84, 146, 52, 34),
    );
    _region(
      canvas,
      MuscleRegion.spinalErectors,
      const Rect.fromLTWH(101, 92, 8, 84),
    );
    _region(
      canvas,
      MuscleRegion.spinalErectors,
      const Rect.fromLTWH(111, 92, 8, 84),
    );
    _region(canvas, MuscleRegion.triceps, const Rect.fromLTWH(48, 98, 19, 45));
    _region(canvas, MuscleRegion.triceps, const Rect.fromLTWH(153, 98, 19, 45));
    _region(
      canvas,
      MuscleRegion.forearms,
      const Rect.fromLTWH(46, 145, 18, 51),
    );
    _region(
      canvas,
      MuscleRegion.forearms,
      const Rect.fromLTWH(156, 145, 18, 51),
    );
    _region(canvas, MuscleRegion.glutes, const Rect.fromLTWH(75, 178, 31, 42));
    _region(canvas, MuscleRegion.glutes, const Rect.fromLTWH(114, 178, 31, 42));
    _region(
      canvas,
      MuscleRegion.hamstrings,
      const Rect.fromLTWH(76, 222, 29, 57),
    );
    _region(
      canvas,
      MuscleRegion.hamstrings,
      const Rect.fromLTWH(115, 222, 29, 57),
    );
    _region(canvas, MuscleRegion.calves, const Rect.fromLTWH(78, 282, 25, 57));
    _region(canvas, MuscleRegion.calves, const Rect.fromLTWH(117, 282, 25, 57));
  }

  void _region(Canvas canvas, MuscleRegion region, Rect rect) {
    final paint = Paint()..color = _color(coverage.region(region).level);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      paint,
    );
  }

  Color _color(CoverageLevel level) => switch (level) {
    CoverageLevel.untrained => const Color(0xFFE7EAE9),
    CoverageLevel.light => const Color(0xFFDDF0EB),
    CoverageLevel.moderate => const Color(0xFF9FD5C8),
    CoverageLevel.sufficient => const Color(0xFF33A78F),
    CoverageLevel.high => const Color(0xFF087966),
  };

  @override
  bool shouldRepaint(covariant MuscleCoveragePainter oldDelegate) =>
      oldDelegate.coverage != coverage || oldDelegate.view != view;
}
