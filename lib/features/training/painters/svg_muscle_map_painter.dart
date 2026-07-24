import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/muscle_region_svg_mapping.dart';
import '../models/training_coverage.dart';

class SvgMuscleScene {
  const SvgMuscleScene._({
    required this.size,
    required this.view,
    required this.scale,
    required this.offset,
    required this.paths,
  });

  final Size size;
  final MuscleBodyView view;
  final double scale;
  final Offset offset;
  final List<SvgMusclePath> paths;

  static SvgMuscleScene layout(Size size, MuscleBodyView view) {
    final scale = math.min(
      size.width / MuscleSvgAsset.viewBox.width,
      size.height / MuscleSvgAsset.viewBox.height,
    );
    final offset = Offset(
      (size.width - MuscleSvgAsset.viewBox.width * scale) / 2,
      (size.height - MuscleSvgAsset.viewBox.height * scale) / 2,
    );
    return SvgMuscleScene._(
      size: size,
      view: view,
      scale: scale,
      offset: offset,
      paths: MuscleSvgAsset.pathsFor(view),
    );
  }

  Offset toViewBox(Offset point) =>
      Offset((point.dx - offset.dx) / scale, (point.dy - offset.dy) / scale);

  Offset toCanvas(Offset point) =>
      Offset(offset.dx + point.dx * scale, offset.dy + point.dy * scale);

  Rect canvasBoundsFor(String id) {
    final path = paths.singleWhere((item) => item.id == id).path;
    final bounds = path.getBounds();
    return Rect.fromLTRB(
      offset.dx + bounds.left * scale,
      offset.dy + bounds.top * scale,
      offset.dx + bounds.right * scale,
      offset.dy + bounds.bottom * scale,
    );
  }

  MuscleRegion? hitTest(Offset point) {
    final local = toViewBox(point);
    for (final musclePath in paths.reversed) {
      if (musclePath.path.contains(local)) return musclePath.muscleRegion;
    }
    for (final musclePath in paths.reversed) {
      final slop = musclePath.hitSlop;
      if (slop <= 0) continue;
      for (var index = 0; index < 8; index++) {
        final angle = math.pi * 2 * index / 8;
        final sample = local.translate(
          math.cos(angle) * slop,
          math.sin(angle) * slop,
        );
        if (musclePath.path.contains(sample)) return musclePath.muscleRegion;
      }
    }
    return null;
  }
}

class SvgMuscleMapPainter extends CustomPainter {
  const SvgMuscleMapPainter({
    required this.coverage,
    required this.view,
    required this.primaryColor,
    this.previousCoverage,
    this.coverageProgress = 1,
    this.selectedRegion,
  });

  final TrainingCoverageResult coverage;
  final TrainingCoverageResult? previousCoverage;
  final double coverageProgress;
  final MuscleBodyView view;
  final Color primaryColor;
  final MuscleRegion? selectedRegion;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = SvgMuscleScene.layout(size, view);
    canvas.save();
    canvas.translate(scene.offset.dx, scene.offset.dy);
    canvas.scale(scene.scale);

    final body = MuscleSvgAsset.bodyFor(view);
    canvas.drawShadow(body, const Color(0x262D4540), 13, false);

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8FAF9), Color(0xFFE2E8E5)],
        stops: [0, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 320, 720));
    canvas.drawPath(body, bodyPaint);

    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      const Rect.fromLTWH(94, 98, 132, 248),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.38, -0.42),
          radius: 1.08,
          colors: [Color(0x72FFFFFF), Color(0x00FFFFFF)],
        ).createShader(const Rect.fromLTWH(80, 80, 160, 290)),
    );
    canvas.restore();

    for (final musclePath in scene.paths) {
      _paintRegion(canvas, musclePath);
    }

    final detailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x344A625C);
    for (final detail in MuscleSvgAsset.detailsFor(view)) {
      canvas.drawPath(detail, detailPaint);
    }

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xA25B706A),
    );

    canvas.restore();
  }

  void _paintRegion(Canvas canvas, SvgMusclePath musclePath) {
    final currentLevel = coverage.region(musclePath.muscleRegion).level;
    final previousLevel =
        previousCoverage?.region(musclePath.muscleRegion).level ?? currentLevel;
    final current = svgMuscleCoverageColor(currentLevel, primaryColor);
    final previous = svgMuscleCoverageColor(previousLevel, primaryColor);
    final color = Color.lerp(previous, current, coverageProgress) ?? current;
    final selected = musclePath.muscleRegion == selectedRegion;
    final bounds = musclePath.path.getBounds();

    if (selected) {
      canvas.drawShadow(
        musclePath.path,
        primaryColor.withValues(alpha: 0.34),
        8,
        false,
      );
    }

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, selected ? 0.18 : 0.12)!,
          color,
          Color.lerp(color, const Color(0xFF173D36), selected ? 0.14 : 0.06)!,
        ],
        stops: const [0, 0.54, 1],
      ).createShader(bounds);
    canvas.drawPath(musclePath.path, fill);

    canvas.drawPath(
      musclePath.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.55 : 0.72
        ..strokeJoin = StrokeJoin.round
        ..color = selected
            ? Color.lerp(primaryColor, const Color(0xFF004F50), 0.25)!
            : const Color(0x32475F59),
    );

    if (selected) {
      canvas.drawPath(
        musclePath.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SvgMuscleMapPainter oldDelegate) =>
      oldDelegate.coverage != coverage ||
      oldDelegate.previousCoverage != previousCoverage ||
      oldDelegate.coverageProgress != coverageProgress ||
      oldDelegate.view != view ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.selectedRegion != selectedRegion;
}

Color svgMuscleCoverageColor(CoverageLevel level, Color primaryColor) =>
    switch (level) {
      CoverageLevel.untrained => const Color(0xFFDCE4E1),
      CoverageLevel.light => Color.lerp(
        const Color(0xFFF2F5F4),
        primaryColor,
        0.16,
      )!,
      CoverageLevel.moderate => Color.lerp(
        const Color(0xFFEAF1EF),
        primaryColor,
        0.43,
      )!,
      CoverageLevel.sufficient => primaryColor,
      CoverageLevel.high => Color.lerp(
        primaryColor,
        const Color(0xFF004F50),
        0.46,
      )!,
    };
