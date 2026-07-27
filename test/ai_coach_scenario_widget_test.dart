import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_suggestion.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_scenario_service.dart';
import 'package:goat_app/features/ai_coach/widgets/ai_coach_explanation_card.dart';
import 'package:goat_app/features/ai_coach/widgets/ai_suggestion_action_sheet.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/progression_recommendation.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/analytics/pages/weekly_review_page.dart';
import 'package:goat_app/features/home/widgets/home_ai_card.dart';
import 'package:goat_app/features/training/widgets/rest_timer_card.dart';
import 'package:goat_app/features/training/widgets/training_recommendation_card.dart';
import 'package:goat_app/models/progression_target.dart';
import 'package:goat_app/models/rest_prescription.dart';

void main() {
  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets(
      'shared explanation surfaces fit ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final explanation = _nutritionExplanation();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AiCoachExplanationCard(explanation: explanation),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('ai-explanation-evidence')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ai-evidence-sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('ai-explanation-follow-up')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ai-follow-up-sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('home card keeps compact nutrition integration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAiCard(
            content: '',
            isLoading: false,
            onRefresh: () {},
            onClose: () {},
            explanation: _nutritionExplanation(),
          ),
        ),
      ),
    );

    expect(find.text('GOAT 营养建议'), findsOneWidget);
    expect(find.text('本周记录 3 / 7 天'), findsOneWidget);
    expect(find.text('为什么这么说  ›'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progression reason sheet adds structured follow-up', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingRecommendationCard(
            exerciseName: '杠铃平板卧推',
            target: ProgressionTarget(
              targetSets: 3,
              targetRepMin: 8,
              targetRepMax: 10,
            ),
            recommendation: ProgressionRecommendation(
              exerciseId: 'bench',
              type: ProgressionRecommendationType.keep,
              dataQuality: ProgressionDataQuality.high,
              reasons: [ProgressionReason.targetRepsIncomplete],
              requiresUserConfirmation: true,
            ),
            referenceWeightKg: 80,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('training-recommendation-reasons')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progression-ai-explanation')), findsOneWidget);
    expect(find.text('问 GOAT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest detail preserves immediate timer and opens evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RestTimerCard(
              remainingSeconds: 200,
              totalSeconds: 210,
              exerciseName: '杠铃平板卧推',
              nextSetLabel: '80 kg × 8',
              onStartNextSet: () {},
              onSkipRest: () {},
              onExtend: () {},
              onChangeExerciseRest: () {},
              onRestoreRecommended: () {},
              recommendation: const RestRecommendation(
                recommendedSeconds: 210,
                plannedSeconds: 210,
                baseSeconds: 150,
                modifierSeconds: 60,
                source: RestSource.exerciseProfile,
                reasonCodes: [
                  RestReasonCode.standardCompound,
                  RestReasonCode.rirZero,
                ],
                transitionType: RestTransitionType.betweenSets,
              ),
              setType: 'working',
              rir: 0,
            ),
          ),
        ),
      ),
    );

    expect(find.text('03:20'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rest-detailed-explanation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-evidence-sheet')), findsOneWidget);
    expect(find.textContaining('210 秒'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly review keeps facts primary and coach section secondary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyReviewPage(
          training: _training(),
          nutrition: _nutrition(),
          coachSuggestions: [
            const AiCoachScenarioService().restSuggestion(
              id: 'weekly-rest',
              templateId: 'push',
              exerciseId: 'bench',
              exerciseName: '卧推',
              fixedSeconds: 180,
            ),
          ],
          onOpenSuggestion: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('weekly-training-review')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-coach-review')), findsOneWidget);
    expect(find.text('GOAT 本周观察'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggestion action sheet previews and returns modified action', (
    tester,
  ) async {
    AiSuggestionActionDecision? decision;
    final suggestion = const AiCoachScenarioService().restSuggestion(
      id: 'rest',
      templateId: 'push',
      exerciseId: 'bench',
      exerciseName: '卧推',
      fixedSeconds: 180,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                decision = await AiSuggestionActionSheet.show(
                  context,
                  suggestion: suggestion,
                  currentLabel: 'GOAT 推荐',
                  updatedLabel: '固定 3:00',
                  impactLabel: 'Push Day · 卧推',
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-suggestion-rest-seconds')),
      '210',
    );
    await tester.tap(find.byKey(const Key('ai-suggestion-confirm-apply')));
    await tester.pumpAndSettle();

    expect(decision?.confirmed, isTrue);
    expect(decision?.modifiedAction?.payload['fixedSeconds'], 210);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggestion action sheet returns an explicit rejection reason', (
    tester,
  ) async {
    AiSuggestionActionDecision? decision;
    final suggestion = const AiCoachScenarioService().restSuggestion(
      id: 'rest-feedback',
      templateId: 'push',
      exerciseId: 'bench',
      exerciseName: '卧推',
      fixedSeconds: 180,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                decision = await AiSuggestionActionSheet.show(
                  context,
                  suggestion: suggestion,
                  currentLabel: 'GOAT 推荐',
                  updatedLabel: '固定 3:00',
                  impactLabel: 'Push Day · 卧推',
                );
              },
              child: const Text('打开反馈'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开反馈'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不适合我'));
    await tester.tap(find.text('暂不采用'));
    await tester.pumpAndSettle();

    expect(decision?.confirmed, isFalse);
    expect(decision?.feedbackType, SuggestionFeedbackType.notForMe);
    expect(tester.takeException(), isNull);
  });
}

dynamic _nutritionExplanation() => const AiCoachScenarioService().nutrition(
  review: _nutrition(),
  calorieTarget: 2000,
  memories: const [],
);

WeeklyNutritionReview _nutrition() => WeeklyNutritionReview(
  dateRange: AnalyticsDateRange(
    start: DateTime(2026, 7, 19),
    end: DateTime(2026, 7, 25),
  ),
  recordedDays: 3,
  dataQuality: WeeklyReviewDataQuality.partial,
  reasons: const [WeeklyReviewReason.partialNutritionLogging],
  weightTrend: WeightTrend(
    anchorDate: DateTime(2026, 7, 25),
    windowDays: 7,
    readingCount: 3,
    dataQuality: WeightTrendDataQuality.partial,
    sevenDayAverageKg: 70,
  ),
  averageCalories: 1950,
  averageProtein: 145,
  averageCarbs: 210,
  averageFat: 62,
);

WeeklyTrainingReview _training() => WeeklyTrainingReview(
  dateRange: AnalyticsDateRange(
    start: DateTime(2026, 7, 19),
    end: DateTime(2026, 7, 25),
  ),
  trainingDays: 3,
  sessionCount: 3,
  completedSets: 27,
  effectiveSets: 24,
  muscleGroups: const [],
  totalVolume: 9000,
  dataQuality: WeeklyReviewDataQuality.partial,
  reasons: const [],
);
