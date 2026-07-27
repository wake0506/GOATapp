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
    canvas.save();
    canvas.clipPath(body);

    _paintNeutralPart(canvas, MuscleSvgAsset.headFor(view), isHead: true);
    for (final part in MuscleSvgAsset.coreSurfacePartsFor(view)) {
      _paintNeutralPart(canvas, part);
    }
    for (final part in MuscleSvgAsset.handPartsFor(view)) {
      _paintNeutralPart(canvas, part);
    }
    for (final part in MuscleSvgAsset.footPartsFor(view)) {
      _paintNeutralPart(canvas, part);
    }

    for (final tendon in MuscleSvgAsset.tendonsFor(view)) {
      final bounds = tendon.getBounds();
      canvas.drawPath(
        tendon,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.28, -0.4),
            radius: 1.08,
            colors: [Color(0xFFF1F5F3), Color(0xFFD3DEDA), Color(0xFFB5C4BF)],
            stops: [0, 0.64, 1],
          ).createShader(bounds),
      );
      canvas.drawPath(
        tendon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.24
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x36516660),
      );
    }

    for (final musclePath in scene.paths) {
      _paintRegion(canvas, musclePath);
    }

    final connectorShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x32C7D2CE);
    final connectorHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.38
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x54FFFFFF);
    for (final connector in MuscleSvgAsset.connectorsFor(view)) {
      canvas.drawPath(connector, connectorShadow);
      canvas.drawPath(connector, connectorHighlight);
    }
    canvas.restore();

    final detailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.52
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x58485E58);
    for (final detail in MuscleSvgAsset.surfaceDetailsFor(view)) {
      canvas.drawPath(detail, detailPaint);
    }

    _paintOutline(canvas, body);

    canvas.restore();
  }

  void _paintOutline(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x1F3B514B),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.94
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xA0475D57),
    );
  }

  void _paintNeutralPart(Canvas canvas, Path path, {bool isHead = false}) {
    final bounds = path.getBounds();
    if (isHead) canvas.drawShadow(path, const Color(0x18263D38), 5, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: isHead
              ? const Alignment(-0.28, -0.34)
              : const Alignment(-0.34, -0.42),
          radius: 1.08,
          colors: const [
            Color(0xFFF2F6F4),
            Color(0xFFD5E0DC),
            Color(0xFFB5C4BF),
          ],
          stops: const [0, 0.62, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHead ? 0.24 : 0.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x4A516660),
    );
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
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.38),
        radius: 1.06,
        colors: [
          Color.lerp(color, Colors.white, selected ? 0.32 : 0.26)!,
          color,
          Color.lerp(color, const Color(0xFF173D36), selected ? 0.2 : 0.13)!,
        ],
        stops: const [0, 0.56, 1],
      ).createShader(bounds);
    canvas.drawPath(musclePath.path, fill);

    canvas.drawPath(
      musclePath.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.35 : 0.52
        ..strokeJoin = StrokeJoin.round
        ..color = selected
            ? Color.lerp(primaryColor, const Color(0xFF004F50), 0.25)!
            : const Color(0x58516660),
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
