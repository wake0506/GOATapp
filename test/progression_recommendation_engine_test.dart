import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/analytics/models/progression_recommendation.dart';
import 'package:goat_app/features/analytics/services/progression_recommendation_engine.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/models/progression_target.dart';
import 'package:goat_app/models/training.dart';

void main() {
  const engine = ProgressionRecommendationEngine();
  const target = ProgressionTarget(
    targetSets: 3,
    targetRepMin: 8,
    targetRepMax: 10,
    weightStepKg: 2.5,
  );

  test('returns insufficient data without matching history', () {
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: const [],
      target: target,
    );
    expect(result.type, ProgressionRecommendationType.insufficientData);
    expect(result.dataQuality, ProgressionDataQuality.insufficient);
    expect(result.reasons, contains(ProgressionReason.insufficientHistory));
  });

  test('does not invent a target for legacy templates', () {
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history('2026-07-20', [10, 10, 10]),
      ],
      target: null,
    );
    expect(result.type, ProgressionRecommendationType.keep);
    expect(
      result.reasons,
      contains(ProgressionReason.missingProgressionTarget),
    );
    expect(result.suggestedWeightKg, isNull);
  });

  test('increases weight only when every target set reaches the maximum', () {
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history('2026-07-20', [10, 10, 10], rirs: [2, 2, 3]),
        _history('2026-07-13', [9, 9, 9], rirs: [2, 2, 2]),
      ],
      target: target,
    );
    expect(result.type, ProgressionRecommendationType.increaseWeight);
    expect(result.suggestedWeightKg, 82.5);
    expect(result.dataQuality, ProgressionDataQuality.high);
    expect(
      result.reasons,
      containsAll([
        ProgressionReason.allTargetRepsCompleted,
        ProgressionReason.highRirReserve,
      ]),
    );
    expect(result.requiresUserConfirmation, isTrue);
  });

  test('10 10 9 increases reps rather than weight', () {
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history('2026-07-20', [10, 10, 9]),
      ],
      target: target,
    );
    expect(result.type, ProgressionRecommendationType.increaseReps);
    expect(result.suggestedWeightKg, isNull);
  });

  test(
    'one underperformance keeps weight but repeated failure decreases it',
    () {
      final one = engine.recommend(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        completedSessions: [
          _history('2026-07-20', [8, 7, 6], rirs: [1, 0, 0]),
        ],
        target: target,
      );
      expect(one.type, ProgressionRecommendationType.keep);

      final repeated = engine.recommend(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        completedSessions: [
          _history('2026-07-20', [8, 7, 6], rirs: [1, 0, 0]),
          _history('2026-07-13', [7, 7, 6], rirs: [0, 0, 0]),
        ],
        target: target,
      );
      expect(repeated.type, ProgressionRecommendationType.decreaseWeight);
      expect(
        repeated.reasons,
        contains(ProgressionReason.repeatedUnderperformance),
      );
    },
  );

  test(
    'stable IDs isolate replacements and legacy exact-name fallback is low quality',
    () {
      final replacementOnly = _history(
        '2026-07-20',
        [10, 10, 10],
        exerciseId: 'incline',
        name: 'Bench',
      );
      final isolated = engine.recommend(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        completedSessions: [replacementOnly],
        target: target,
      );
      expect(isolated.type, ProgressionRecommendationType.insufficientData);

      final legacy = engine.recommend(
        exerciseId: 'bench',
        exerciseName: ' Bench ',
        completedSessions: [
          _history(
            '2026-07-20',
            [10, 10, 10],
            exerciseId: null,
            name: 'bench',
            rirs: [2, 2, 2],
          ),
        ],
        target: target,
      );
      expect(legacy.type, ProgressionRecommendationType.increaseWeight);
      expect(legacy.dataQuality, ProgressionDataQuality.low);
      expect(legacy.reasons, contains(ProgressionReason.legacyNameMatch));
    },
  );

  test(
    'missing RIR lowers quality but does not block completed progression',
    () {
      final result = engine.recommend(
        exerciseId: 'bench',
        exerciseName: 'Bench',
        completedSessions: [
          _history('2026-07-20', [10, 10, 10]),
          _history('2026-07-13', [10, 10, 10]),
        ],
        target: target,
      );
      expect(result.type, ProgressionRecommendationType.increaseWeight);
      expect(result.dataQuality, ProgressionDataQuality.medium);
      expect(result.reasons, contains(ProgressionReason.missingRir));
    },
  );

  test('low reserve or failure context keeps weight after maximum reps', () {
    final lowReserve = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history('2026-07-20', [10, 10, 10], rirs: [1, 1, 1]),
      ],
      target: target,
    );
    expect(lowReserve.type, ProgressionRecommendationType.keep);

    final failure = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history(
          '2026-07-20',
          [10, 10, 10],
          rirs: [2, 2, 2],
          includeFailureContext: true,
        ),
      ],
      target: target,
    );
    expect(failure.type, ProgressionRecommendationType.keep);
    expect(failure.reasons, contains(ProgressionReason.reachedFailure));
  });

  test('does not invent an exact weight without a configured step', () {
    const noStepTarget = ProgressionTarget(
      targetSets: 3,
      targetRepMin: 8,
      targetRepMax: 10,
    );
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history('2026-07-20', [10, 10, 10], rirs: [2, 2, 2]),
      ],
      target: noStepTarget,
    );
    expect(result.type, ProgressionRecommendationType.increaseWeight);
    expect(result.suggestedWeightKg, isNull);
  });

  test('warmup drop and amrap are excluded from primary progression sets', () {
    final history = _history('2026-07-20', [8, 8, 8]);
    history.exercises.single.sets.addAll([
      SetRecord(reps: 20, setType: TrainingSetType.warmup),
      SetRecord(reps: 20, setType: TrainingSetType.drop),
      SetRecord(reps: 20, setType: TrainingSetType.amrap),
    ]);
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [history],
      target: target,
    );
    expect(result.type, ProgressionRecommendationType.increaseReps);
  });

  test('superset sets are usable with explicit lower-quality context', () {
    final result = engine.recommend(
      exerciseId: 'bench',
      exerciseName: 'Bench',
      completedSessions: [
        _history(
          '2026-07-20',
          [10, 10, 10],
          rirs: [2, 2, 2],
          setType: TrainingSetType.superset,
        ),
        _history(
          '2026-07-13',
          [10, 10, 10],
          rirs: [2, 2, 2],
          setType: TrainingSetType.superset,
        ),
      ],
      target: target,
    );
    expect(result.type, ProgressionRecommendationType.increaseWeight);
    expect(result.dataQuality, ProgressionDataQuality.medium);
    expect(result.reasons, contains(ProgressionReason.supersetContext));
    expect(result.basedOnSessionId, '2026-07-20');
  });
}

TrainingSession _history(
  String date,
  List<int> reps, {
  String? exerciseId = 'bench',
  String name = 'Bench',
  List<int?>? rirs,
  bool includeFailureContext = false,
  TrainingSetType setType = TrainingSetType.working,
}) => TrainingSession(
  id: date,
  name: 'Training',
  date: date,
  exercises: [
    TrainingExercise(
      exerciseId: exerciseId,
      exerciseName: name,
      bodyPart: 'chest',
      sets: [
        for (var index = 0; index < reps.length; index++)
          SetRecord(
            weight: 80,
            reps: reps[index],
            setType: setType,
            rir: rirs?[index],
            completedAt: DateTime.parse('$date 10:00:00'),
          ),
        if (includeFailureContext)
          SetRecord(
            weight: 80,
            reps: 1,
            setType: TrainingSetType.failure,
            reachedFailure: true,
            completedAt: DateTime.parse('$date 10:05:00'),
          ),
      ],
    ),
  ],
);
