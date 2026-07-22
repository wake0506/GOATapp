import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/progression_recommendation.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/analytics/pages/weekly_review_page.dart';
import 'package:goat_app/features/analytics/widgets/weight_trend_summary.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/pages/active_training_page.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/widgets/progression_target_sheet.dart';
import 'package:goat_app/features/training/widgets/training_recommendation_card.dart';
import 'package:goat_app/features/training/widgets/training_template_manager_sheet.dart';
import 'package:goat_app/models/progression_target.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  const target = ProgressionTarget(
    targetSets: 3,
    targetRepMin: 8,
    targetRepMax: 10,
    weightStepKg: 2.5,
  );

  testWidgets('progression target sheet creates validates and clears targets', (
    tester,
  ) async {
    ProgressionTargetEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ProgressionTargetSheet.show(context);
              },
              child: const Text('目标'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('progression-target-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-sets')),
      '0',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-min')),
      '8',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '10',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('progression-target-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-sets')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-min')),
      '10',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '8',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('progression-target-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-min')),
      '8',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '10',
    );
    await tester.tap(find.byKey(const Key('progression-target-save')));
    await tester.pumpAndSettle();
    expect(result?.target?.targetSets, 3);
    expect(result?.target?.weightStepKg, isNull);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progression-target-sets')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-min')),
      '8',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '10',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-step')),
      '0',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('progression-target-save')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('existing progression target can be cleared', (tester) async {
    ProgressionTargetEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ProgressionTargetSheet.show(
                  context,
                  initialTarget: target,
                );
              },
              child: const Text('编辑目标'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progression-target-clear')));
    await tester.pumpAndSettle();
    expect(result?.cleared, isTrue);
  });

  testWidgets('existing progression target can be edited without defaults', (
    tester,
  ) async {
    ProgressionTargetEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ProgressionTargetSheet.show(
                  context,
                  initialTarget: target,
                );
              },
              child: const Text('修改目标'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('修改目标'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '12',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('progression-target-save')));
    await tester.pumpAndSettle();
    expect(result?.target?.targetRepMax, 12);
    expect(result?.target?.weightStepKg, 2.5);
  });

  testWidgets('template exercise creates edits and clears its target', (
    tester,
  ) async {
    final exercise = exerciseCatalog.first;
    TrainingTemplate? result;
    TrainingTemplate existing = TrainingTemplate(
      id: 'plan',
      name: 'Plan',
      exerciseIds: [exercise.id],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await TrainingTemplateEditorSheet.show(
                  context,
                  catalog: exerciseCatalog,
                  existing: existing,
                );
              },
              child: const Text('编辑方案'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑方案'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('template-target-${exercise.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progression-target-sets')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-min')),
      '8',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-max')),
      '10',
    );
    await tester.enterText(
      find.byKey(const Key('progression-target-step')),
      '2.5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('progression-target-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3×8–10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('training-template-save')));
    await tester.pumpAndSettle();
    expect(result?.targetFor(exercise.id)?.weightStepKg, 2.5);

    existing = result!;
    await tester.tap(find.text('编辑方案'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('template-target-${exercise.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progression-target-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-template-save')));
    await tester.pumpAndSettle();
    expect(result?.targetFor(exercise.id), isNull);
  });

  testWidgets('recommendation card maps actions reasons and data quality', (
    tester,
  ) async {
    const recommendation = ProgressionRecommendation(
      exerciseId: 'bench',
      type: ProgressionRecommendationType.increaseWeight,
      dataQuality: ProgressionDataQuality.medium,
      reasons: [
        ProgressionReason.allTargetRepsCompleted,
        ProgressionReason.missingRir,
        ProgressionReason.supersetContext,
        ProgressionReason.legacyNameMatch,
      ],
      requiresUserConfirmation: true,
      suggestedWeightKg: 82.5,
      targetSets: 3,
      targetRepMin: 8,
      targetRepMax: 10,
    );
    var applied = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingRecommendationCard(
            target: target,
            recommendation: recommendation,
            onApply: () => applied++,
          ),
        ),
      ),
    );
    expect(find.text('建议下次 82.5 kg'), findsOneWidget);
    expect(find.text('数据一般'), findsOneWidget);
    await tester.tap(find.byKey(const Key('training-recommendation-reasons')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('training-recommendation-reason-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('部分历史缺少 RIR'), findsOneWidget);
    expect(find.textContaining('超级组训练'), findsOneWidget);
    expect(find.textContaining('旧历史中的同名动作'), findsOneWidget);
    Navigator.of(
      tester.element(
        find.byKey(const Key('training-recommendation-reason-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-recommendation-apply')));
    expect(applied, 1);
  });

  testWidgets('missing target never shows a guessed progression action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingRecommendationCard(target: null, recommendation: null),
        ),
      ),
    );
    expect(find.text('暂无精确递进建议'), findsOneWidget);
    expect(
      find.byKey(const Key('training-recommendation-apply')),
      findsNothing,
    );
  });

  testWidgets('recommendation UI covers every deterministic action', (
    tester,
  ) async {
    final cases = <ProgressionRecommendationType, String>{
      ProgressionRecommendationType.increaseWeight: '可以增加重量',
      ProgressionRecommendationType.increaseReps: '优先增加完成次数',
      ProgressionRecommendationType.keep: '保持当前重量',
      ProgressionRecommendationType.decreaseWeight: '建议适当降低重量',
      ProgressionRecommendationType.insufficientData: '数据不足，暂不生成递进建议',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingRecommendationCard(
              target: target,
              recommendation: ProgressionRecommendation(
                exerciseId: 'bench',
                type: entry.key,
                dataQuality:
                    entry.key == ProgressionRecommendationType.insufficientData
                    ? ProgressionDataQuality.insufficient
                    : ProgressionDataQuality.low,
                reasons: const [ProgressionReason.supersetContext],
                requiresUserConfirmation: true,
                targetSets: 3,
                targetRepMin: 8,
                targetRepMax: 10,
              ),
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('active recommendation applies only after confirmation', (
    tester,
  ) async {
    final bench = exerciseCatalog.first;
    final template = TrainingTemplate(
      id: 'source-plan',
      name: 'Plan',
      exerciseIds: [bench.id],
      progressionTargets: {bench.id: target},
    );
    final draft = TrainingSession(
      id: 'draft',
      name: 'Plan',
      date: '2026-07-21',
      exercises: [
        TrainingExercise(
          exerciseId: bench.id,
          exerciseName: bench.name,
          bodyPart: bench.bodyPart,
          progressionTarget: template.targetFor(bench.id),
          sets: [
            for (var index = 0; index < 3; index++)
              SetRecord(id: 'set-$index', setType: TrainingSetType.working),
          ],
        ),
      ],
    );
    final history = TrainingSession(
      id: 'history',
      name: 'History',
      date: '2026-07-20',
      exercises: [
        TrainingExercise(
          exerciseId: bench.id,
          exerciseName: bench.name,
          bodyPart: bench.bodyPart,
          sets: [
            for (var index = 0; index < 3; index++)
              SetRecord(
                weight: 80,
                reps: 10,
                rir: 2,
                setType: TrainingSetType.working,
                completedAt: DateTime(2026, 7, 20),
              ),
          ],
        ),
      ],
    );
    final repository = InMemoryTrainingRepository(completedSessions: [history]);
    final engine = TrainingSessionEngine(
      repository: repository,
      clock: () => DateTime(2026, 7, 21, 10),
    );
    final active = await engine.startSession(
      activeSessionId: 'active',
      draft: draft,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTrainingPage(
          initialSession: active,
          engine: engine,
          repository: repository,
          catalog: exerciseCatalog,
          onSessionChanged: (_) {},
          onFinished: (_) async {},
          clock: () => DateTime(2026, 7, 21, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (await repository.loadActiveSession())!
          .draft
          .exercises
          .single
          .sets
          .first
          .weight,
      80,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('training-recommendation-apply')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('training-recommendation-apply')));
    await tester.pumpAndSettle();
    expect(
      (await repository.loadActiveSession())!
          .draft
          .exercises
          .single
          .sets
          .first
          .weight,
      80,
    );
    await tester.tap(find.byKey(const Key('training-recommendation-confirm')));
    await tester.pumpAndSettle();
    expect(
      (await repository.loadActiveSession())!
          .draft
          .exercises
          .single
          .sets
          .first
          .weight,
      82.5,
    );
    expect(template.targetFor(bench.id)?.weightStepKg, 2.5);
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets(
      'weekly review and trend summary fit ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final trend = WeightTrend(
          anchorDate: DateTime(2026, 7, 21),
          windowDays: 7,
          readingCount: 7,
          dataQuality: WeightTrendDataQuality.complete,
          latestMeasuredWeightKg: 71.2,
          sevenDayAverageKg: 71.48,
          change7dKg: -0.35,
          change14dKg: -0.6,
        );
        final range = AnalyticsDateRange(
          start: DateTime(2026, 7, 15),
          end: DateTime(2026, 7, 21),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: WeeklyReviewPage(
              training: WeeklyTrainingReview(
                dateRange: range,
                trainingDays: 4,
                sessionCount: 5,
                completedSets: 50,
                effectiveSets: 41,
                muscleGroups: const [],
                totalVolume: 12000,
                dataQuality: WeeklyReviewDataQuality.complete,
                reasons: const [WeeklyReviewReason.completeWeek],
              ),
              nutrition: WeeklyNutritionReview(
                dateRange: range,
                recordedDays: 6,
                averageCalories: 2150,
                averageProtein: 148,
                averageCarbs: 230,
                averageFat: 65,
                weightTrend: trend,
                dataQuality: WeeklyReviewDataQuality.partial,
                reasons: const [WeeklyReviewReason.partialNutritionLogging],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('weekly-review-page')), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
        expect(find.byKey(const Key('weekly-weight-review')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WeightTrendSummary(trend: trend)),
          ),
        );
        expect(find.text('-0.35 kg'), findsOneWidget);
        expect(find.text('-0.60 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ProgressionTargetSheet(initialTarget: target)),
          ),
        );
        expect(
          find.byKey(const Key('progression-target-save')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TrainingRecommendationCard(
                target: target,
                recommendation: ProgressionRecommendation(
                  exerciseId: 'bench',
                  type: ProgressionRecommendationType.keep,
                  dataQuality: ProgressionDataQuality.medium,
                  reasons: [ProgressionReason.missingRir],
                  requiresUserConfirmation: true,
                  targetSets: 3,
                  targetRepMin: 8,
                  targetRepMax: 10,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const Key('training-recommendation-card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
