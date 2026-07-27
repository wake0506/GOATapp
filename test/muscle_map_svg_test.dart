import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/muscle_region_svg_mapping.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/features/training/painters/svg_muscle_map_painter.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/features/training/widgets/interactive_svg_muscle_map.dart';

void main() {
  const calculator = TrainingCoverageCalculator();
  const marsGreen = Color(0xFF008C8C);

  test('all 21 regions use explicit stable SVG-derived path mapping', () {
    final allPaths = [
      ...MuscleSvgAsset.frontPaths,
      ...MuscleSvgAsset.backPaths,
    ];
    final ids = allPaths.map((path) => path.id).toList();
    expect(unmappedMuscleRegionsSvg, isEmpty);
    expect(muscleRegionSvgMapping.keys.toSet(), MuscleRegion.values.toSet());
    expect(ids.toSet().length, ids.length);
    for (final mapping in muscleRegionSvgMapping.values) {
      final mappedIds = [...mapping.frontPathIds, ...mapping.backPathIds];
      expect(mappedIds, isNotEmpty);
      expect(mappedIds, everyElement(isIn(ids)));
    }
  });

  test('front and back assets keep cached continuous body geometry', () {
    expect(MuscleSvgAsset.frontBody.computeMetrics().length, 1);
    expect(MuscleSvgAsset.backBody.computeMetrics().length, 1);
    expect(identical(MuscleSvgAsset.frontBody, MuscleSvgAsset.backBody), false);
    expect(MuscleSvgAsset.frontBody.getBounds().height, greaterThan(690));
    expect(MuscleSvgAsset.backBody.getBounds().height, greaterThan(690));
    expect(MuscleSvgAsset.frontDetails.length, greaterThanOrEqualTo(15));
    expect(MuscleSvgAsset.backDetails.length, greaterThanOrEqualTo(15));
    expect(MuscleSvgAsset.frontConnectors, isNotEmpty);
    expect(MuscleSvgAsset.backConnectors, isNotEmpty);
    expect(MuscleSvgAsset.frontSurfaceParts.length, greaterThanOrEqualTo(20));
    expect(MuscleSvgAsset.backSurfaceParts.length, greaterThanOrEqualTo(20));
    expect(
      MuscleSvgAsset.frontSurfaceDetails.every(
        (path) => path.getBounds().top > 100,
      ),
      true,
    );
    expect(
      MuscleSvgAsset.backSurfaceDetails.every(
        (path) => path.getBounds().top > 100,
      ),
      true,
    );
    for (final path in [
      MuscleSvgAsset.frontHead,
      MuscleSvgAsset.backHead,
      ...MuscleSvgAsset.frontSurfaceParts,
      ...MuscleSvgAsset.backSurfaceParts,
    ]) {
      final bounds = path.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(MuscleSvgAsset.viewBox.width));
      expect(bounds.bottom, lessThanOrEqualTo(MuscleSvgAsset.viewBox.height));
    }
    expect(
      identical(MuscleSvgAsset.frontPaths, MuscleSvgAsset.frontPaths),
      true,
    );
    expect(identical(MuscleSvgAsset.backPaths, MuscleSvgAsset.backPaths), true);
  });

  test('coverage palette is neutral plus four Mars Green-derived levels', () {
    final colors = CoverageLevel.values
        .map((level) => svgMuscleCoverageColor(level, marsGreen))
        .toList();
    expect(colors.toSet().length, CoverageLevel.values.length);
    expect(colors.first, const Color(0xFFDCE4E1));
    expect(colors[3], marsGreen);
  });

  test('path hit testing resolves front and back anatomical regions', () {
    const size = Size(320, 720);

    void expectPath(MuscleBodyView view, String id, MuscleRegion expected) {
      final scene = SvgMuscleScene.layout(size, view);
      expect(scene.hitTest(scene.canvasBoundsFor(id).center), expected);
    }

    expectPath(
      MuscleBodyView.front,
      'front.midChest.left',
      MuscleRegion.midChest,
    );
    expectPath(MuscleBodyView.front, 'front.quads.left', MuscleRegion.quads);
    expectPath(MuscleBodyView.back, 'back.lats.left', MuscleRegion.lats);
    expectPath(
      MuscleBodyView.back,
      'back.hamstrings.left',
      MuscleRegion.hamstrings,
    );
    expectPath(
      MuscleBodyView.back,
      'back.rearDelts.left',
      MuscleRegion.rearDelts,
    );
  });

  testWidgets('controller focus and drag switch the front and back assets', (
    tester,
  ) async {
    final controller = SvgMuscleMapController();
    addTearDown(controller.dispose);
    final coverage = calculator.calculateSessions(sessions: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: marsGreen),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 720,
            child: InteractiveSvgMuscleMap(
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
    expect(find.byKey(const Key('svg-muscle-map-back')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('interactive-svg-muscle-map')),
      const Offset(60, 0),
    );
    await tester.pump();
    expect(find.byKey(const Key('svg-muscle-map-front')), findsOneWidget);
  });

  testWidgets('tap on an actual chest path selects the mapped region', (
    tester,
  ) async {
    MuscleRegion? selected;
    final coverage = calculator.calculateSessions(sessions: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: marsGreen),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 720,
            child: InteractiveSvgMuscleMap(
              coverage: coverage,
              reducedMotion: true,
              onRegionSelected: (region) => selected = region,
            ),
          ),
        ),
      ),
    );

    final map = find.byKey(const Key('interactive-svg-muscle-map'));
    final scene = SvgMuscleScene.layout(
      tester.getSize(map),
      MuscleBodyView.front,
    );
    await tester.tapAt(
      tester.getTopLeft(map) +
          scene.canvasBoundsFor('front.midChest.left').center,
    );
    await tester.pump();
    expect(selected, MuscleRegion.midChest);
  });
}
