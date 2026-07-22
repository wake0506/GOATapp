import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/muscle_region_3d_mapping.dart';
import '../models/training_coverage.dart';

class MuscleMap3DHitRegion {
  const MuscleMap3DHitRegion({
    required this.id,
    required this.region,
    required this.path,
    required this.depth,
    required this.visibility,
  });

  final String id;
  final MuscleRegion region;
  final Path path;
  final double depth;
  final double visibility;
}

class MuscleMap3DScene {
  const MuscleMap3DScene(this.hitRegions);

  final List<MuscleMap3DHitRegion> hitRegions;

  MuscleRegion? hitTest(Offset position) {
    final candidates =
        hitRegions
            .where(
              (region) =>
                  region.visibility >= 0.28 && region.path.contains(position),
            )
            .toList()
          ..sort((left, right) => right.depth.compareTo(left.depth));
    return candidates.isEmpty ? null : candidates.first.region;
  }

  static MuscleMap3DScene layout(Size size, double yaw) {
    final projection = _Projection(size: size, yaw: yaw);
    final regions = <MuscleMap3DHitRegion>[];
    for (final patch in musclePatch3DSpecs) {
      final normal = _normalFor(patch.surface, yaw);
      final visibility = ((normal + 0.18) / 0.62).clamp(0.0, 1.0);
      if (visibility <= 0.04) continue;
      final projected = projection.point(patch.x, patch.y, patch.z);
      final width =
          patch.width *
          projection.scale *
          projected.scale *
          (0.30 + 0.70 * normal.abs());
      final height = patch.height * projection.scale * projected.scale;
      final rect = Rect.fromCenter(
        center: projected.offset,
        width: width.clamp(5.0, double.infinity),
        height: height.clamp(7.0, double.infinity),
      );
      regions.add(
        MuscleMap3DHitRegion(
          id: patch.id,
          region: patch.region,
          path: Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                rect,
                Radius.circular(math.min(rect.width, rect.height) * 0.42),
              ),
            ),
          depth: projected.depth,
          visibility: visibility,
        ),
      );
    }
    regions.sort((left, right) => left.depth.compareTo(right.depth));
    return MuscleMap3DScene(regions);
  }
}

class MuscleMap3DPainter extends CustomPainter {
  const MuscleMap3DPainter({
    required this.coverage,
    required this.yaw,
    this.selectedRegion,
  });

  final TrainingCoverageResult coverage;
  final double yaw;
  final MuscleRegion? selectedRegion;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);
    final projection = _Projection(size: size, yaw: yaw);
    _paintFloorShadow(canvas, projection);

    final bodyParts = [
      for (final part in _bodyParts)
        (part: part, point: projection.point(part.x, part.y, part.z)),
    ]..sort((left, right) => left.point.depth.compareTo(right.point.depth));
    for (final entry in bodyParts) {
      _paintBodyPart(canvas, projection, entry.part, entry.point);
    }

    final scene = MuscleMap3DScene.layout(size, yaw);
    for (final hit in scene.hitRegions) {
      final level = coverage.region(hit.region).level;
      final selected = selectedRegion == hit.region;
      final bounds = hit.path.getBounds();
      final baseColor = muscleCoverage3DColor(level);
      final materialOpacity = level == CoverageLevel.untrained
          ? 0.42 + hit.visibility * 0.10
          : 0.72 + hit.visibility * 0.28;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(baseColor, Colors.white, 0.18)!,
            baseColor,
            Color.lerp(baseColor, const Color(0xFF004F47), 0.18)!,
          ],
        ).createShader(bounds)
        ..color = Colors.white.withValues(alpha: materialOpacity);
      canvas.drawPath(hit.path, paint);
      canvas.drawPath(
        hit.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.4 : 0.75
          ..color = selected
              ? const Color(0xFF006E63)
              : Colors.white.withValues(alpha: 0.38 * hit.visibility),
      );
      if (selected) {
        canvas.drawPath(
          hit.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..color = const Color(0x5533A78F),
        );
      }
    }
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final radius = math.min(size.width * 0.45, size.height * 0.42);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF8FBFA), Color(0xFFEFF4F2), Color(0x00EFF4F2)],
          stops: [0, 0.70, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x16008C7A),
    );
  }

  void _paintFloorShadow(Canvas canvas, _Projection projection) {
    final floor = projection.point(0, 1.76, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: floor.offset.translate(0, 8),
        width: projection.scale * 0.92,
        height: projection.scale * 0.13,
      ),
      Paint()
        ..color = const Color(0x1A16312B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  void _paintBodyPart(
    Canvas canvas,
    _Projection projection,
    _BodyPart3D part,
    _ProjectedPoint point,
  ) {
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    final projectedWidth = math.sqrt(
      math.pow(part.width * c, 2) + math.pow(part.depth * s, 2),
    );
    final width = projectedWidth * projection.scale * point.scale;
    final height = part.height * projection.scale * point.scale;
    final rect = Rect.fromCenter(
      center: point.offset,
      width: width,
      height: height,
    );
    final radius = Radius.circular(math.min(width, height) * part.roundness);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-0.9 + math.sin(yaw) * 0.25, -1),
          end: const Alignment(1, 1),
          colors: const [
            Color(0xFFFCFDFD),
            Color(0xFFE4EAE8),
            Color(0xFFCCD5D2),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x80BEC9C6),
    );
  }

  @override
  bool shouldRepaint(covariant MuscleMap3DPainter oldDelegate) =>
      oldDelegate.coverage != coverage ||
      oldDelegate.yaw != yaw ||
      oldDelegate.selectedRegion != selectedRegion;
}

Color muscleCoverage3DColor(CoverageLevel level) => switch (level) {
  CoverageLevel.untrained => const Color(0xFFE2E7E5),
  CoverageLevel.light => const Color(0xFFD6EEE7),
  CoverageLevel.moderate => const Color(0xFF8DCEBD),
  CoverageLevel.sufficient => const Color(0xFF2EA58C),
  CoverageLevel.high => const Color(0xFF087565),
};

double _normalFor(MuscleSurface3D surface, double yaw) {
  final (nx, nz) = switch (surface) {
    MuscleSurface3D.front => (0.0, 1.0),
    MuscleSurface3D.back => (0.0, -1.0),
    MuscleSurface3D.left => (-1.0, 0.0),
    MuscleSurface3D.right => (1.0, 0.0),
  };
  return -nx * math.sin(yaw) + nz * math.cos(yaw);
}

class _Projection {
  const _Projection({required this.size, required this.yaw});

  final Size size;
  final double yaw;

  double get scale => math.min(size.width / 1.82, size.height / 3.78);

  _ProjectedPoint point(double x, double y, double z) {
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    final rotatedX = x * c + z * s;
    final rotatedZ = -x * s + z * c;
    final perspective = 1 + rotatedZ * 0.11;
    return _ProjectedPoint(
      offset: Offset(
        size.width / 2 + rotatedX * scale * perspective,
        size.height * 0.48 + y * scale * perspective,
      ),
      depth: rotatedZ,
      scale: perspective,
    );
  }
}

class _ProjectedPoint {
  const _ProjectedPoint({
    required this.offset,
    required this.depth,
    required this.scale,
  });

  final Offset offset;
  final double depth;
  final double scale;
}

class _BodyPart3D {
  const _BodyPart3D({
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.depth,
    required this.height,
    this.roundness = 0.46,
  });

  final double x;
  final double y;
  final double z;
  final double width;
  final double depth;
  final double height;
  final double roundness;
}

const _bodyParts = <_BodyPart3D>[
  _BodyPart3D(x: 0, y: -1.48, z: 0, width: 0.36, depth: 0.31, height: 0.42),
  _BodyPart3D(x: 0, y: -1.17, z: 0, width: 0.18, depth: 0.16, height: 0.18),
  _BodyPart3D(
    x: 0,
    y: -0.67,
    z: 0,
    width: 0.92,
    depth: 0.45,
    height: 0.76,
    roundness: 0.30,
  ),
  _BodyPart3D(
    x: 0,
    y: -0.15,
    z: 0,
    width: 0.60,
    depth: 0.38,
    height: 0.48,
    roundness: 0.27,
  ),
  _BodyPart3D(
    x: 0,
    y: 0.26,
    z: 0,
    width: 0.64,
    depth: 0.43,
    height: 0.36,
    roundness: 0.35,
  ),
  _BodyPart3D(x: -0.47, y: -0.75, z: 0, width: 0.28, depth: 0.28, height: 0.26),
  _BodyPart3D(x: 0.47, y: -0.75, z: 0, width: 0.28, depth: 0.28, height: 0.26),
  _BodyPart3D(x: -0.58, y: -0.38, z: 0, width: 0.23, depth: 0.23, height: 0.69),
  _BodyPart3D(x: 0.58, y: -0.38, z: 0, width: 0.23, depth: 0.23, height: 0.69),
  _BodyPart3D(x: -0.62, y: -0.04, z: 0, width: 0.20, depth: 0.20, height: 0.21),
  _BodyPart3D(x: 0.62, y: -0.04, z: 0, width: 0.20, depth: 0.20, height: 0.21),
  _BodyPart3D(x: -0.64, y: 0.16, z: 0, width: 0.18, depth: 0.19, height: 0.58),
  _BodyPart3D(x: 0.64, y: 0.16, z: 0, width: 0.18, depth: 0.19, height: 0.58),
  _BodyPart3D(x: -0.20, y: 0.35, z: 0, width: 0.37, depth: 0.41, height: 0.31),
  _BodyPart3D(x: 0.20, y: 0.35, z: 0, width: 0.37, depth: 0.41, height: 0.31),
  _BodyPart3D(x: -0.20, y: 0.78, z: 0, width: 0.35, depth: 0.39, height: 0.88),
  _BodyPart3D(x: 0.20, y: 0.78, z: 0, width: 0.35, depth: 0.39, height: 0.88),
  _BodyPart3D(x: -0.20, y: 1.18, z: 0, width: 0.27, depth: 0.30, height: 0.25),
  _BodyPart3D(x: 0.20, y: 1.18, z: 0, width: 0.27, depth: 0.30, height: 0.25),
  _BodyPart3D(x: -0.20, y: 1.48, z: 0, width: 0.25, depth: 0.29, height: 0.66),
  _BodyPart3D(x: 0.20, y: 1.48, z: 0, width: 0.25, depth: 0.29, height: 0.66),
];
