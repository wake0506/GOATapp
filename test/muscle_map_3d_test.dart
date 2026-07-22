import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/muscle_region_3d_mapping.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/features/training/painters/muscle_map_3d_painter.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/features/training/widgets/interactive_muscle_map_3d.dart';

void main() {
  const emptyCoverage = TrainingCoverageCalculator();

  test('all stable muscle regions have explicit unique 3D visual mapping', () {
    expect(unmappedMuscleRegions3D, isEmpty);
    expect(muscleRegion3DMapping.keys.toSet(), MuscleRegion.values.toSet());
    final ids = musclePatch3DSpecs.map((patch) => patch.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final mapping in muscleRegion3DMapping.values) {
      expect(mapping.visualRegionIds, isNotEmpty);
      expect(mapping.visualRegionIds, everyElement(isIn(ids)));
    }
  });

  test('coverage palette keeps five ordered neutral-to-GOAT-green levels', () {
    final colors = CoverageLevel.values.map(muscleCoverage3DColor).toList();
    expect(colors.toSet().length, CoverageLevel.values.length);
    expect(colors.first, const Color(0xFFE2E7E5));
    expect(colors.last, const Color(0xFF087565));
  });

  test('front and back scene picking resolves large anatomical regions', () {
    const size = Size(320, 410);
    void expectPatch(double yaw, String id, MuscleRegion expected) {
      final scene = MuscleMap3DScene.layout(size, yaw);
      final patch = scene.hitRegions.singleWhere((item) => item.id == id);
      expect(scene.hitTest(patch.path.getBounds().center), expected);
    }

    expectPatch(0, 'midChest.left', MuscleRegion.midChest);
    expectPatch(0, 'quads.left', MuscleRegion.quads);
    expectPatch(math.pi, 'lats.left', MuscleRegion.lats);
    expectPatch(math.pi, 'hamstrings.left', MuscleRegion.hamstrings);
    expectPatch(math.pi, 'rearDelts.left', MuscleRegion.rearDelts);
  });

  testWidgets('controller focus and drag keep rotation state stable', (
    tester,
  ) async {
    final controller = MuscleMap3DController();
    addTearDown(controller.dispose);
    final coverage = emptyCoverage.calculateSessions(sessions: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 410,
            child: InteractiveMuscleMap3D(
              coverage: coverage,
              controller: controller,
              reducedMotion: true,
              onRegionSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    controller.focusRegion(MuscleRegion.lats);
    await tester.pump();
    MuscleMap3DPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-map-3d-painter')),
                )
                .painter
            as MuscleMap3DPainter;
    expect(painter().yaw.abs(), closeTo(math.pi, 0.01));
    expect(painter().selectedRegion, MuscleRegion.lats);
    await tester.drag(
      find.byKey(const Key('interactive-muscle-map-3d')),
      const Offset(60, 0),
    );
    await tester.pump();
    expect(painter().selectedRegion, isNull);
    expect(painter().yaw.abs(), lessThan(math.pi));
  });

  testWidgets('tap on a visible model patch selects the mapped region', (
    tester,
  ) async {
    MuscleRegion? selected;
    final coverage = emptyCoverage.calculateSessions(sessions: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 410,
            child: InteractiveMuscleMap3D(
              coverage: coverage,
              reducedMotion: true,
              onRegionSelected: (region) => selected = region,
            ),
          ),
        ),
      ),
    );
    const size = Size(320, 410);
    final scene = MuscleMap3DScene.layout(size, 0);
    final chest = scene.hitRegions.singleWhere(
      (item) => item.id == 'midChest.left',
    );
    final map = find.byKey(const Key('interactive-muscle-map-3d'));
    await tester.tapAt(tester.getTopLeft(map) + chest.path.getBounds().center);
    await tester.pump();
    expect(selected, MuscleRegion.midChest);
  });
}
