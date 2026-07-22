import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/analytics/pages/weekly_review_page.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/exercise_recommendation.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/features/training/pages/training_coverage_page.dart';
import 'package:goat_app/features/training/painters/muscle_map_3d_painter.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/models/training.dart';

void main() {
  final completedAt = DateTime(2026, 7, 20, 10);

  SetRecord completedSet(String id) => SetRecord(
    id: id,
    reps: 8,
    setType: TrainingSetType.working,
    completedAt: completedAt,
  );

  TrainingCoverageResult coverage({int sets = 0, bool unresolved = false}) {
    if (sets == 0) {
      return const TrainingCoverageCalculator().calculateSessions(sessions: []);
    }
    final id = unresolved ? 'clean' : 'barbell_flat_bench_press';
    return const TrainingCoverageCalculator().calculateSession(
      session: TrainingSession(
        id: 'session-$sets-$unresolved',
        name: 'Training',
        date: '2026-07-20',
        exercises: [
          TrainingExercise(
            exerciseId: id,
            exerciseName: unresolved ? '高翻' : '杠铃平板卧推',
            bodyPart: unresolved ? '全身/体能' : '胸部',
            sets: [
              for (var index = 0; index < sets; index++)
                completedSet('$id-$index'),
            ],
          ),
        ],
      ),
      isActiveSession: true,
    );
  }

  TrainingSession backSession() => TrainingSession(
    id: 'back-day',
    name: 'Back Day',
    date: '2026-07-20',
    exercises: [
      TrainingExercise(
        exerciseId: 'lat_pulldown',
        exerciseName: '高位下拉',
        bodyPart: '背部',
        sets: [
          for (var index = 0; index < 3; index++) completedSet('lat-$index'),
        ],
      ),
      TrainingExercise(
        exerciseId: 'pull_up',
        exerciseName: '引体向上',
        bodyPart: '背部',
        sets: [completedSet('pull-up')],
      ),
      TrainingExercise(
        exerciseId: 'seated_cable_row',
        exerciseName: '坐姿划船',
        bodyPart: '背部',
        sets: [SetRecord(id: 'row-pending')],
      ),
    ],
  );

  TrainingCoverageResult backCoverage() => const TrainingCoverageCalculator()
      .calculateSession(session: backSession(), isActiveSession: true);

  Widget page({
    TrainingCoverageResult? current,
    TrainingCoverageResult? today,
    TrainingCoverageResult? week,
    TrainingSession? activeSession,
    Future<void> Function(ExerciseRecommendationResult)? onApply,
    MuscleMap3DInitializer initialize3D = initializeProceduralMuscleMap3D,
  }) => MaterialApp(
    home: TrainingCoveragePage(
      currentCoverage: current,
      todayCoverage: today ?? coverage(),
      weeklyCoverage: week ?? coverage(sets: 5),
      catalog: exerciseCatalog,
      activeSession: activeSession,
      onApplyRecommendation: onApply,
      initialize3D: initialize3D,
    ),
  );

  testWidgets('current today and seven-day scopes stay isolated', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        current: coverage(sets: 2),
        today: coverage(sets: 3),
        week: coverage(sets: 5),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本次'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('近 7 天'), findsOneWidget);

    MuscleMap3DPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-map-3d-painter')),
                )
                .painter
            as MuscleMap3DPainter;

    expect(painter().coverage.completedEffectiveSets, 2);
    await tester.tap(find.text('今日'));
    await tester.pump();
    expect(painter().coverage.completedEffectiveSets, 3);
    await tester.tap(find.text('近 7 天'));
    await tester.pump();
    expect(painter().coverage.completedEffectiveSets, 5);
  });

  testWidgets('front back shortcuts and drag update only the 3D camera', (
    tester,
  ) async {
    await tester.pumpWidget(page(today: coverage(sets: 2)));
    await tester.pumpAndSettle();
    MuscleMap3DPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-map-3d-painter')),
                )
                .painter
            as MuscleMap3DPainter;
    expect(painter().yaw, closeTo(0, 0.01));
    await tester.tap(find.text('背面'));
    await tester.pumpAndSettle();
    expect(painter().yaw.abs(), closeTo(3.14159, 0.03));
    final beforeDrag = painter().yaw;
    await tester.drag(
      find.byKey(const Key('interactive-muscle-map-3d')),
      const Offset(70, 0),
    );
    await tester.pump();
    expect(painter().yaw, isNot(closeTo(beforeDrag, 0.05)));
    expect(painter().coverage.completedEffectiveSets, 2);
  });

  testWidgets('failed initialization keeps 2D detail and honest labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        today: coverage(sets: 1, unresolved: true),
        initialize3D: () async => false,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('muscle-map-3d-fallback-notice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('muscle-coverage-map')), findsOneWidget);
    expect(find.text('精细元数据有限'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('renderer exception also falls back without blank state', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        today: coverage(sets: 2),
        initialize3D: () async => throw StateError('renderer unavailable'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle-coverage-map')), findsOneWidget);
    expect(find.byKey(const Key('training-coverage-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('region detail uses structured contribution sets and movement', (
    tester,
  ) async {
    final session = TrainingSession(
      id: 'back-complete',
      name: 'Back Day',
      date: '2026-07-20',
      exercises: [
        TrainingExercise(
          exerciseId: 'lat_pulldown',
          exerciseName: '高位下拉',
          bodyPart: '背部',
          sets: [
            completedSet('lat-1'),
            completedSet('lat-2'),
            completedSet('lat-3'),
          ],
        ),
        TrainingExercise(
          exerciseId: 'seated_cable_row',
          exerciseName: '坐姿划船',
          bodyPart: '背部',
          sets: [completedSet('row-1'), completedSet('row-2')],
        ),
      ],
    );
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session,
      isActiveSession: true,
    );
    await tester.pumpWidget(page(today: result));
    await tester.pumpAndSettle();
    final region = find.byKey(const Key('coverage-region-lats'));
    await tester.scrollUntilVisible(
      region,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(region);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle-region-detail-sheet')), findsOneWidget);
    expect(find.text('背阔肌'), findsWidgets);
    expect(find.text('高位下拉'), findsOneWidget);
    expect(find.text('3 组'), findsWidgets);
    expect(find.textContaining('垂直拉'), findsWidgets);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets(
    'coverage recommendation mutates only after explicit confirmation',
    (tester) async {
      var applied = 0;
      final result = backCoverage();
      await tester.pumpWidget(
        page(
          current: result,
          today: result,
          activeSession: backSession(),
          onApply: (_) async => applied++,
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('coverage-recommendation-card'));
      await tester.scrollUntilVisible(
        card,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('坐姿划船'), findsOneWidget);
      expect(applied, 0);
      final open = find.byKey(const Key('coverage-recommendation-open'));
      await tester.ensureVisible(open);
      await tester.pump();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coverage-recommendation-detail')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('coverage-recommendation-detail-apply')),
      );
      await tester.pumpAndSettle();
      expect(applied, 0);
      await tester.tap(
        find.byKey(const Key('coverage-recommendation-confirm')),
      );
      await tester.pumpAndSettle();
      expect(applied, 1);
    },
  );

  testWidgets('ignoring coverage recommendation never mutates the session', (
    tester,
  ) async {
    var applied = 0;
    final result = backCoverage();
    await tester.pumpWidget(
      page(
        current: result,
        today: result,
        activeSession: backSession(),
        onApply: (_) async => applied++,
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('coverage-recommendation-card'));
    await tester.scrollUntilVisible(
      card,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final ignore = find.byKey(const Key('coverage-recommendation-ignore'));
    await tester.ensureVisible(ignore);
    await tester.pump();
    await tester.tap(ignore);
    await tester.pump();
    expect(find.byKey(const Key('coverage-recommendation-card')), findsNothing);
    expect(applied, 0);
  });

  testWidgets('no active session hides current scope and recommendation', (
    tester,
  ) async {
    await tester.pumpWidget(page(today: coverage(sets: 2)));
    await tester.pumpAndSettle();
    expect(find.text('本次'), findsNothing);
    expect(find.byKey(const Key('coverage-recommendation-card')), findsNothing);
  });

  testWidgets('weekly review keeps static summary and opens 3D on demand', (
    tester,
  ) async {
    var opened = false;
    final range = AnalyticsDateRange(
      start: DateTime(2026, 7, 14),
      end: DateTime(2026, 7, 20),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyReviewPage(
          training: WeeklyTrainingReview(
            dateRange: range,
            trainingDays: 1,
            sessionCount: 1,
            completedSets: 5,
            effectiveSets: 5,
            muscleGroups: const [],
            totalVolume: 0,
            dataQuality: WeeklyReviewDataQuality.partial,
            reasons: const [WeeklyReviewReason.partialTrainingHistory],
          ),
          nutrition: WeeklyNutritionReview(
            dateRange: range,
            recordedDays: 0,
            weightTrend: WeightTrend(
              anchorDate: DateTime(2026, 7, 20),
              windowDays: 7,
              readingCount: 0,
              dataQuality: WeightTrendDataQuality.unavailable,
            ),
            dataQuality: WeeklyReviewDataQuality.insufficient,
            reasons: const [WeeklyReviewReason.partialNutritionLogging],
          ),
          coverage: coverage(sets: 5),
          onOpenCoverage: () => opened = true,
        ),
      ),
    );
    expect(find.byKey(const Key('weekly-coverage-review')), findsOneWidget);
    expect(find.textContaining('覆盖较多：胸部'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-open-3d-coverage')));
    expect(opened, isTrue);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(800, 360),
    const Size(1024, 800),
  ]) {
    testWidgets('coverage experience fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(page(today: coverage(sets: 3)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('training-coverage-page')), findsOneWidget);
      expect(
        find.byKey(const Key('interactive-muscle-map-3d')),
        findsOneWidget,
      );
    });
  }
}
