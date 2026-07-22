import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/analytics/pages/weekly_review_page.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/features/training/pages/training_coverage_page.dart';
import 'package:goat_app/features/training/painters/muscle_coverage_painter.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/models/training.dart';

void main() {
  TrainingCoverageResult coverage({int sets = 0, bool unresolved = false}) {
    if (sets == 0) {
      return const TrainingCoverageCalculator().calculateSessions(sessions: []);
    }
    final id = unresolved ? 'clean' : 'barbell_flat_bench_press';
    final exercise = TrainingExercise(
      exerciseId: id,
      exerciseName: unresolved ? '高翻' : '杠铃平板卧推',
      bodyPart: unresolved ? '全身/体能' : '胸部',
      sets: [
        for (var index = 0; index < sets; index++)
          SetRecord(
            id: 'set-$index',
            reps: 8,
            setType: TrainingSetType.working,
            completedAt: DateTime(2026, 7, 20),
          ),
      ],
    );
    return const TrainingCoverageCalculator().calculateSession(
      session: TrainingSession(
        id: 'session',
        name: 'Training',
        date: '2026-07-20',
        exercises: [exercise],
      ),
      isActiveSession: true,
    );
  }

  Widget page({
    TrainingCoverageResult? session,
    TrainingCoverageResult? week,
  }) => MaterialApp(
    home: TrainingCoveragePage(
      sessionCoverage: session ?? coverage(),
      weeklyCoverage: week ?? coverage(sets: 5),
      catalog: exerciseCatalog,
    ),
  );

  testWidgets('front back and time-scope toggles keep discrete coverage', (
    tester,
  ) async {
    await tester.pumpWidget(page(session: coverage(sets: 2)));
    expect(find.byKey(const Key('muscle-coverage-map')), findsOneWidget);
    expect(find.text('本次 / 今日'), findsOneWidget);
    expect(find.text('近 7 天'), findsOneWidget);
    var painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-coverage-map')),
                )
                .painter
            as MuscleCoveragePainter;
    expect(painter.view, MuscleMapView.front);

    await tester.tap(find.text('背面'));
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-coverage-map')),
                )
                .painter
            as MuscleCoveragePainter;
    expect(painter.view, MuscleMapView.back);

    await tester.tap(find.text('近 7 天'));
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('muscle-coverage-map')),
                )
                .painter
            as MuscleCoveragePainter;
    expect(
      painter.coverage.muscleCoverage.any(
        (item) => item.level == CoverageLevel.high,
      ),
      isTrue,
    );
  });

  testWidgets('zero and unresolved coverage use honest quality labels', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    expect(find.text('暂无训练记录'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -430));
    await tester.pump();
    expect(find.text('当前还没有覆盖较多的区域'), findsOneWidget);

    await tester.pumpWidget(page(session: coverage(sets: 1, unresolved: true)));
    await tester.pump();
    expect(find.text('精细元数据有限'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('weekly review includes restrained coverage summary', (
    tester,
  ) async {
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
        ),
      ),
    );
    expect(find.byKey(const Key('weekly-coverage-review')), findsOneWidget);
    expect(find.textContaining('覆盖较多：胸部'), findsOneWidget);
    expect(find.textContaining('必须'), findsNothing);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('coverage page fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(page(session: coverage(sets: 3)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('training-coverage-page')), findsOneWidget);
    });
  }
}
