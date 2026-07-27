import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/ai_coach/models/ai_coach_response.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/models/ai_suggestion.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_response_validator.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_scenario_service.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_explanation_service.dart';
import 'package:goat_app/features/ai_coach/services/ai_context_assembler.dart';
import 'package:goat_app/features/ai_coach/services/ai_suggestion_service.dart';
import 'package:goat_app/features/ai_coach/services/knowledge_retrieval_service.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/progression_recommendation.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/exercise_recommendation.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/models/progression_target.dart';
import 'package:goat_app/models/rest_prescription.dart';

void main() {
  const service = AiCoachScenarioService();

  group('nutrition scenario', () {
    for (final days in [0, 2, 7]) {
      test('handles $days recorded days without inventing calorie changes', () {
        final result = service.nutrition(
          review: _nutrition(days),
          calorieTarget: 2000,
          memories: const [],
        );

        expect(
          result.headline,
          days == 0 ? contains('没有饮食记录') : contains('$days / 7'),
        );
        expect(
          result.suggestions.any(
            (item) =>
                item.proposedAction?.type ==
                AiProposedActionType.updateCalorieGoal,
          ),
          isFalse,
        );
        expect(result.partialData, days > 0 && days < 7);
        expect(result.insufficientEvidence, days < 3);
        if (days == 2) {
          expect(result.explanation, contains('数据不完整'));
          expect(result.explanation, contains('已记录日期'));
        }
      });
    }

    test('uses coaching style only for expression', () {
      final dataStyle = service.nutrition(
        review: _nutrition(7),
        calorieTarget: 2000,
        memories: [_memory(AiProfileCategory.coachingStyle, '数据型')],
      );
      final directStyle = service.nutrition(
        review: _nutrition(7),
        calorieTarget: 2000,
        memories: [_memory(AiProfileCategory.coachingStyle, '简洁直接')],
      );

      expect(dataStyle.explanation, startsWith('本周记录 7 / 7 天'));
      expect(
        directStyle.explanation.length,
        lessThan(dataStyle.explanation.length),
      );
    });

    test(
      'handles a missing goal and unavailable or available trend safely',
      () {
        final unavailable = service.nutrition(
          review: _nutrition(0),
          calorieTarget: null,
          memories: const [],
        );
        final available = service.nutrition(
          review: _nutrition(7),
          calorieTarget: null,
          memories: const [],
        );

        expect(unavailable.evidence.last.value, '趋势暂不可用');
        expect(available.evidence.last.value, contains('70.20 kg'));
        expect(unavailable.suggestions, isEmpty);
        expect(available.suggestions, isEmpty);
      },
    );
  });

  group('progression scenario', () {
    for (final type in ProgressionRecommendationType.values) {
      test('preserves ${type.name} as the deterministic action', () {
        final result = service.progression(
          recommendation: _progression(type),
          exerciseName: '杠铃平板卧推',
          memories: const [],
          target: const ProgressionTarget(
            targetSets: 3,
            targetRepMin: 8,
            targetRepMax: 10,
          ),
          referenceWeightKg: 80,
        );

        expect(result.deterministicAction, type.name);
        expect(result.suggestions, isEmpty);
        if (type == ProgressionRecommendationType.keep) {
          expect(result.explanation, contains('保持'));
          expect(result.explanation, isNot(contains('建议加 2.5')));
        }
      });
    }
  });

  group('rest scenario', () {
    test('explains standard compound RIR0 without changing 210 seconds', () {
      const recommendation = RestRecommendation(
        recommendedSeconds: 210,
        plannedSeconds: 210,
        baseSeconds: 150,
        modifierSeconds: 60,
        source: RestSource.exerciseProfile,
        reasonCodes: [RestReasonCode.standardCompound, RestReasonCode.rirZero],
        transitionType: RestTransitionType.betweenSets,
      );

      final result = service.rest(
        recommendation: recommendation,
        exerciseName: '杠铃平板卧推',
        memories: const [],
        setType: 'working',
        rir: 0,
      );

      expect(result.recommendedSeconds, 210);
      expect(result.explanation, contains('150'));
      expect(result.explanation, contains('+60'));
      expect(result.explanation, contains('210'));
    });

    test('explains fixed and session override boundaries', () {
      final fixed = service.rest(
        recommendation: const RestRecommendation(
          recommendedSeconds: 150,
          plannedSeconds: 180,
          baseSeconds: 150,
          modifierSeconds: 0,
          source: RestSource.templateFixed,
          reasonCodes: [
            RestReasonCode.standardCompound,
            RestReasonCode.userFixed,
          ],
          transitionType: RestTransitionType.betweenSets,
        ),
        exerciseName: '卧推',
        memories: const [],
      );
      final override = service.rest(
        recommendation: const RestRecommendation(
          recommendedSeconds: 150,
          plannedSeconds: 210,
          baseSeconds: 150,
          modifierSeconds: 0,
          source: RestSource.sessionExerciseOverride,
          reasonCodes: [RestReasonCode.sessionOverride],
          transitionType: RestTransitionType.betweenSets,
          isUserOverridden: true,
        ),
        exerciseName: '卧推',
        memories: const [],
      );

      expect(fixed.explanation, contains('固定'));
      expect(override.explanation, contains('不会自动写回训练方案'));
      expect(override.recommendedSeconds, 150);
    });

    test('explains failure modifier and keeps current-only override local', () {
      final failure = service.rest(
        recommendation: const RestRecommendation(
          recommendedSeconds: 240,
          plannedSeconds: 240,
          baseSeconds: 150,
          modifierSeconds: 90,
          source: RestSource.exerciseProfile,
          reasonCodes: [
            RestReasonCode.standardCompound,
            RestReasonCode.reachedFailure,
          ],
          transitionType: RestTransitionType.betweenSets,
        ),
        exerciseName: '卧推',
        memories: const [],
        reachedFailure: true,
      );
      final currentOnly = service.rest(
        recommendation: const RestRecommendation(
          recommendedSeconds: 150,
          plannedSeconds: 180,
          baseSeconds: 150,
          modifierSeconds: 0,
          source: RestSource.sessionExerciseOverride,
          reasonCodes: [RestReasonCode.sessionOverride],
          transitionType: RestTransitionType.betweenSets,
          isUserOverridden: true,
        ),
        exerciseName: '卧推',
        memories: const [],
      );

      expect(failure.recommendedSeconds, 240);
      expect(failure.explanation, contains('达到力竭'));
      expect(currentOnly.explanation, contains('不会自动写回训练方案'));
      expect(currentOnly.suggestions, isEmpty);
    });
  });

  group('coverage scenario', () {
    test('uses only the candidate supplied by recommendation engine', () {
      final result = service.coverage(
        coverage: _coverage(),
        candidates: [_rowCandidate],
        memories: const [],
        selectedRegion: MuscleRegion.midBack,
      );

      expect(result.recommendedExerciseId, _rowCandidate.exercise.id);
      expect(result.headline, contains(_rowCandidate.exercise.name));
      expect(result.explanation, contains('水平拉'));
    });

    test('does not invent a candidate when engine returns none', () {
      final result = service.coverage(
        coverage: _coverage(),
        candidates: const [],
        memories: const [],
      );

      expect(result.recommendedExerciseId, isNull);
      expect(result.insufficientEvidence, isTrue);
      expect(result.explanation, contains('不会临时发明动作'));
    });
  });

  group('weekly scenario', () {
    test('keeps summary short and labels partial nutrition evidence', () {
      final result = service.weekly(
        training: _training(sessionCount: 3),
        nutrition: _nutrition(3),
        coverage: _coverage(),
        memories: const [],
      );

      expect(result.explanation.split('\n').length, lessThanOrEqualTo(3));
      expect(result.partialData, isTrue);
      expect(result.explanation, isNot(contains('激素')));
      expect(result.explanation, isNot(contains('代谢受损')));
    });

    test('limits actionable suggestions to three', () {
      final suggestions = List.generate(
        5,
        (index) => service.restSuggestion(
          id: 's$index',
          templateId: 'push',
          exerciseId: 'bench',
          exerciseName: '卧推',
          fixedSeconds: 180,
        ),
      );
      final result = service.weekly(
        training: _training(sessionCount: 1),
        nutrition: _nutrition(7),
        coverage: null,
        memories: const [],
        suggestions: suggestions,
      );

      expect(result.suggestions, hasLength(3));
    });

    test('handles no-data, training-only, and nutrition-only weeks', () {
      final noData = service.weekly(
        training: _training(sessionCount: 0),
        nutrition: _nutrition(0),
        coverage: null,
        memories: const [],
      );
      final trainingOnly = service.weekly(
        training: _training(sessionCount: 2),
        nutrition: _nutrition(0),
        coverage: _coverage(),
        memories: const [],
      );
      final nutritionOnly = service.weekly(
        training: _training(sessionCount: 0),
        nutrition: _nutrition(7),
        coverage: null,
        memories: const [],
      );

      expect(noData.insufficientEvidence, isTrue);
      expect(noData.explanation, contains('记录还不足'));
      expect(trainingOnly.explanation, contains('2 次训练'));
      expect(trainingOnly.explanation, isNot(contains('饮食记录')));
      expect(nutritionOnly.explanation, contains('饮食记录 7 / 7'));
    });

    test('reports only supplied previous-period comparisons', () {
      final result = service.weekly(
        training: _training(sessionCount: 3, previousSessionCount: 2),
        nutrition: _nutrition(7, previousAverageCalories: 1800),
        coverage: null,
        memories: const [],
      );

      expect(result.explanation, contains('上一周期完成 2 次训练'));
      expect(result.explanation, contains('上一周期已记录日均 1800 kcal'));
    });
  });

  group('context and evidence boundaries', () {
    test('progression excludes nutrition memories and unrelated raw data', () {
      final retrieved = const KnowledgeRetrievalService().retrieve(
        const KnowledgeRetrievalRequest(
          taskType: AiCoachTaskType.progressionExplanation,
        ),
      );
      final context = const AiContextAssembler().assemble(
        AiContextRequest(
          taskType: AiCoachTaskType.progressionExplanation,
          memories: [
            _memory(AiProfileCategory.coachingStyle, '详细解释'),
            _memory(AiProfileCategory.nutritionPreference, '低盐'),
          ],
          retrievedKnowledge: retrieved,
          dataEvidence: const {
            'progression_recommendation': {'action': 'keep'},
            'nutrition_summary': {'days': 7},
          },
          currentTaskContext: const {
            'progressionRecommendation': {'action': 'keep'},
            'nutritionSummary': {'days': 7},
          },
        ),
      );
      final memory = context.payload['approvedMemory'] as List;
      final evidence = context.payload['dataEvidence'] as Map;
      final task = context.payload['taskContext'] as Map;

      expect(memory, hasLength(1));
      expect(memory.single['category'], AiProfileCategory.coachingStyle.name);
      expect(evidence, contains('progression_recommendation'));
      expect(evidence, isNot(contains('nutrition_summary')));
      expect(task, isNot(contains('nutritionSummary')));
    });

    test('validator removes unreturned evidence and knowledge refs', () {
      final retrieved = const KnowledgeRetrievalService().retrieve(
        const KnowledgeRetrievalRequest(
          taskType: AiCoachTaskType.restExplanation,
        ),
      );
      final context = const AiContextAssembler().assemble(
        AiContextRequest(
          taskType: AiCoachTaskType.restExplanation,
          memories: const [],
          retrievedKnowledge: retrieved,
          dataEvidence: const {
            'rest_recommendation': {'recommendedSeconds': 210},
          },
        ),
      );
      final allowedKnowledge = context.allowedKnowledgeRefs.first;
      final validated = const AiCoachResponseValidator().validate(
        AiCoachResponse(
          answer: '解释',
          summary: '解释',
          evidenceRefs: const ['rest_recommendation', 'fake-evidence'],
          knowledgeRefs: [allowedKnowledge, 'fake-knowledge'],
        ),
        context,
      );

      expect(validated.evidenceRefs, ['rest_recommendation']);
      expect(validated.knowledgeRefs, [allowedKnowledge]);
    });

    test('rest and coverage contexts exclude unrelated domain histories', () {
      final restContext = const AiContextAssembler().assemble(
        const AiContextRequest(
          taskType: AiCoachTaskType.restExplanation,
          memories: [],
          retrievedKnowledge: RetrievedKnowledgeContext(
            entries: [],
            sourceRefs: [],
            dataQuality: RetrievedKnowledgeQuality.insufficient,
          ),
          dataEvidence: {
            'rest_recommendation': {'recommendedSeconds': 210},
            'nutrition_summary': {'recordedDays': 7},
          },
          currentTaskContext: {
            'restRecommendation': {'recommendedSeconds': 210},
            'nutritionSummary': {'recordedDays': 7},
          },
        ),
      );
      final coverageContext = const AiContextAssembler().assemble(
        const AiContextRequest(
          taskType: AiCoachTaskType.coverageExplanation,
          memories: [],
          retrievedKnowledge: RetrievedKnowledgeContext(
            entries: [],
            sourceRefs: [],
            dataQuality: RetrievedKnowledgeQuality.insufficient,
          ),
          dataEvidence: {
            'coverage_result': {'effectiveSets': 4},
            'weight_trend': {
              'history': [70, 69.8, 69.7],
            },
          },
          currentTaskContext: {
            'coverage': {'effectiveSets': 4},
            'weightTrend': {
              'history': [70, 69.8, 69.7],
            },
          },
        ),
      );

      expect(
        restContext.payload['dataEvidence'] as Map,
        isNot(contains('nutrition_summary')),
      );
      expect(
        restContext.payload['taskContext'] as Map,
        isNot(contains('nutritionSummary')),
      );
      expect(
        coverageContext.payload['dataEvidence'] as Map,
        isNot(contains('weight_trend')),
      );
      expect(
        coverageContext.payload['taskContext'] as Map,
        isNot(contains('weightTrend')),
      );
    });
  });

  group('suggestion action loop', () {
    final suggestion = service.restSuggestion(
      id: 'rest-1',
      templateId: 'push',
      exerciseId: 'bench',
      exerciseName: '卧推',
      fixedSeconds: 180,
    );

    test('unconfirmed action does not validate or persist', () async {
      var calls = 0;
      final result = await const AiSuggestionApplicationService().apply(
        suggestion: suggestion,
        userConfirmed: false,
        validate: (_) async {
          calls++;
          return true;
        },
        persist: (_) async => calls++,
      );

      expect(result.status, AiSuggestionStatus.proposed);
      expect(calls, 0);
    });

    test('modified action passes modified -> accepted -> applied', () async {
      const modified = AiProposedAction(
        type: AiProposedActionType.updateRestPrescription,
        domainEntityId: 'push',
        payload: {
          'templateId': 'push',
          'exerciseId': 'bench',
          'fixedSeconds': 210,
        },
      );
      AiProposedAction? persisted;
      final recordedStatuses = <AiSuggestionStatus>[];
      final result = await const AiSuggestionApplicationService().apply(
        suggestion: suggestion,
        userConfirmed: true,
        modifiedAction: modified,
        validate: (action) async => action.payload['fixedSeconds'] == 210,
        persist: (action) async => persisted = action,
        onTransition: (value) async => recordedStatuses.add(value.status),
      );

      expect(result.status, AiSuggestionStatus.applied);
      expect(result.proposedAction?.payload['fixedSeconds'], 210);
      expect(persisted, same(modified));
      expect(recordedStatuses, [
        AiSuggestionStatus.modified,
        AiSuggestionStatus.accepted,
        AiSuggestionStatus.applied,
      ]);
    });

    test('invalid action becomes applyFailed and is never persisted', () async {
      var persisted = false;
      final result = await const AiSuggestionApplicationService().apply(
        suggestion: suggestion,
        userConfirmed: true,
        validate: (_) async => false,
        persist: (_) async => persisted = true,
      );

      expect(result.status, AiSuggestionStatus.applyFailed);
      expect(persisted, isFalse);
    });

    test('all feedback kinds survive serialization', () {
      for (final type in SuggestionFeedbackType.values) {
        final feedback = SuggestionFeedback(
          suggestionId: suggestion.id,
          decision: SuggestionDecision.dismissed,
          feedbackType: type,
          createdAt: DateTime(2026, 7, 25),
        );
        expect(
          SuggestionFeedback.fromJson(feedback.toJson()).feedbackType,
          type,
        );
      }
    });
  });

  group('AI failure fallback', () {
    for (final task in [
      AiCoachTaskType.nutrition,
      AiCoachTaskType.coverageExplanation,
      AiCoachTaskType.trainingSummary,
    ]) {
      test('${task.name} network failure keeps structured fallback', () async {
        final response =
            await const AiCoachExplanationService(
              gateway: _FailingGateway(),
            ).explain(
              AiCoachExplanationRequest(
                taskType: task,
                query: '解释',
                memories: const [],
                dataEvidence: const {
                  'nutrition_summary': {'recordedDays': 3},
                  'coverage_result': {'effectiveSets': 4},
                  'weekly_review': {'trainingDays': 2},
                },
              ),
            );

        expect(response.usedFallback, isTrue);
        expect(response.answer, isNotEmpty);
        expect(response.suggestions, isEmpty);
      });
    }

    test('malformed response falls back without throwing', () async {
      final response =
          await const AiCoachExplanationService(
            gateway: _MalformedGateway(),
          ).explain(
            const AiCoachExplanationRequest(
              taskType: AiCoachTaskType.nutrition,
              query: '营养',
              memories: [],
            ),
          );

      expect(response.usedFallback, isTrue);
      expect(response.answer, contains('正常记录饮食'));
    });
  });
}

WeeklyNutritionReview _nutrition(int days, {double? previousAverageCalories}) =>
    WeeklyNutritionReview(
      dateRange: AnalyticsDateRange(
        start: DateTime(2026, 7, 19),
        end: DateTime(2026, 7, 25),
      ),
      recordedDays: days,
      dataQuality: days == 7
          ? WeeklyReviewDataQuality.complete
          : days == 0
          ? WeeklyReviewDataQuality.insufficient
          : WeeklyReviewDataQuality.partial,
      reasons: days == 7
          ? const [WeeklyReviewReason.completeWeek]
          : const [WeeklyReviewReason.partialNutritionLogging],
      weightTrend: WeightTrend(
        anchorDate: DateTime(2026, 7, 25),
        windowDays: 7,
        readingCount: days,
        dataQuality: days == 0
            ? WeightTrendDataQuality.unavailable
            : WeightTrendDataQuality.partial,
        sevenDayAverageKg: days == 0 ? null : 70.2,
        change7dKg: days == 0 ? null : -0.3,
      ),
      averageCalories: days == 0 ? null : 1950,
      averageProtein: days == 0 ? null : 145,
      averageCarbs: days == 0 ? null : 210,
      averageFat: days == 0 ? null : 62,
      previousAverageCalories: previousAverageCalories,
    );

WeeklyTrainingReview _training({
  required int sessionCount,
  int? previousSessionCount,
}) => WeeklyTrainingReview(
  dateRange: AnalyticsDateRange(
    start: DateTime(2026, 7, 19),
    end: DateTime(2026, 7, 25),
  ),
  trainingDays: sessionCount,
  sessionCount: sessionCount,
  completedSets: sessionCount * 9,
  effectiveSets: sessionCount * 8,
  muscleGroups: const [],
  totalVolume: sessionCount * 3000,
  dataQuality: sessionCount == 0
      ? WeeklyReviewDataQuality.insufficient
      : WeeklyReviewDataQuality.partial,
  reasons: sessionCount == 0
      ? const [WeeklyReviewReason.partialTrainingHistory]
      : const [],
  previousSessionCount: previousSessionCount,
);

ProgressionRecommendation _progression(ProgressionRecommendationType type) =>
    ProgressionRecommendation(
      exerciseId: 'bench',
      type: type,
      dataQuality: type == ProgressionRecommendationType.insufficientData
          ? ProgressionDataQuality.insufficient
          : ProgressionDataQuality.high,
      reasons: switch (type) {
        ProgressionRecommendationType.keep => const [
          ProgressionReason.targetRepsIncomplete,
        ],
        ProgressionRecommendationType.increaseWeight => const [
          ProgressionReason.allTargetRepsCompleted,
        ],
        ProgressionRecommendationType.increaseReps => const [
          ProgressionReason.targetRepsIncomplete,
        ],
        ProgressionRecommendationType.decreaseWeight => const [
          ProgressionReason.repeatedUnderperformance,
        ],
        ProgressionRecommendationType.insufficientData => const [
          ProgressionReason.insufficientHistory,
        ],
      },
      requiresUserConfirmation:
          type != ProgressionRecommendationType.insufficientData,
      basedOnSessionId: 's1',
      basedOnSessionDate: DateTime(2026, 7, 24),
    );

TrainingCoverageResult _coverage() => const TrainingCoverageResult(
  sessionIds: ['s1'],
  targetBodyParts: ['背部'],
  targetMuscleGroups: [MuscleGroup.back],
  muscleCoverage: [],
  regionCoverage: [
    RegionCoverageItem(
      region: MuscleRegion.midBack,
      level: CoverageLevel.light,
      contributionUnits: 2,
      contributingExerciseIds: ['lat_pulldown'],
    ),
  ],
  movementPatternCoverage: [
    MovementCoverageItem(
      pattern: ExerciseMovementPattern.verticalPull,
      effectiveSetCount: 6,
      level: CoverageLevel.high,
      contributingExerciseIds: ['lat_pulldown'],
    ),
    MovementCoverageItem(
      pattern: ExerciseMovementPattern.horizontalPull,
      effectiveSetCount: 1,
      level: CoverageLevel.light,
      contributingExerciseIds: [],
    ),
  ],
  completedEffectiveSets: 7,
  dataQuality: CoverageDataQuality.high,
  legacyResolvedExercises: 0,
  unresolvedExerciseIds: [],
);

const _rowCandidate = ExerciseRecommendationResult(
  exercise: ExerciseDefinition(
    id: 'seated_cable_row',
    name: '坐姿划船',
    bodyPart: '背部',
    equipment: '器械',
  ),
  mode: ExerciseRecommendationMode.complementary,
  reasonCodes: [ExerciseRecommendationReason.missingMovementPattern],
  dataQuality: ExerciseRecommendationDataQuality.high,
  targetMuscles: [MuscleGroup.back],
  targetRegions: [MuscleRegion.midBack],
  movementPattern: ExerciseMovementPattern.horizontalPull,
  rank: 1,
);

AiMemoryItem _memory(AiProfileCategory category, String value) => AiMemoryItem(
  id: 'memory-${category.name}',
  category: category,
  value: value,
  sourceType: AiMemorySourceType.userProvided,
  status: AiMemoryStatus.active,
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
  userConfirmed: true,
);

class _FailingGateway implements StructuredAiCoachGateway {
  const _FailingGateway();

  @override
  Future<Object?> generate(Map<String, dynamic> context) async {
    throw StateError('network unavailable');
  }
}

class _MalformedGateway implements StructuredAiCoachGateway {
  const _MalformedGateway();

  @override
  Future<Object?> generate(Map<String, dynamic> context) async => '{bad json';
}
