import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/services/plate_calculator_service.dart';
import 'package:goat_app/features/training/services/superset_service.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/services/warmup_suggestion_service.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  final now = DateTime.utc(2026, 7, 18, 12);

  TrainingSession pairedDraft() => TrainingSession(
    id: 'session-advanced',
    name: 'Superset',
    date: '2026-07-18',
    exercises: [
      TrainingExercise(
        exerciseId: 'bench',
        exerciseName: '杠铃平板卧推',
        bodyPart: '胸部',
        orderIndex: 0,
        sets: List.generate(
          2,
          (index) => SetRecord(
            id: 'a${index + 1}',
            weight: 80,
            reps: 8,
            setType: TrainingSetType.working,
          ),
        ),
      ),
      TrainingExercise(
        exerciseId: 'row',
        exerciseName: '杠铃俯身划船',
        bodyPart: '背部',
        orderIndex: 1,
        sets: List.generate(
          2,
          (index) => SetRecord(
            id: 'b${index + 1}',
            weight: 60,
            reps: 10,
            setType: TrainingSetType.working,
          ),
        ),
      ),
    ],
  );

  group('set type compatibility', () {
    test('round-trips all stable English set types', () {
      for (final type in TrainingSetType.values) {
        final decoded = SetRecord.fromJson(SetRecord(setType: type).toJson());
        expect(decoded.resolvedSetType, type);
      }
    });

    test('keeps failure intent separate from actual failure', () {
      final plannedFailure = SetRecord(
        setType: TrainingSetType.failure,
        reachedFailure: false,
      );
      final actualFailure = SetRecord(
        setType: TrainingSetType.working,
        reachedFailure: true,
      );

      expect(plannedFailure.reachedFailure, isFalse);
      expect(actualFailure.resolvedSetType, TrainingSetType.working);
      expect(actualFailure.reachedFailure, isTrue);
    });

    test('old exercise JSON remains compatible without a superset group', () {
      final exercise = TrainingExercise.fromJson({
        'exerciseName': '卧推',
        'bodyPart': '胸部',
        'sets': <Map<String, dynamic>>[],
      });
      expect(exercise.supersetGroupId, isNull);
    });
  });

  group('superset flow', () {
    test('pairs exactly two exercises with a stable persisted group', () {
      final session = pairedDraft();
      final groupId = const SupersetService().pair(
        session: session,
        firstExerciseId: 'bench',
        secondExerciseId: 'row',
      );
      final restored = TrainingSession.fromJson(session.toJson());

      expect(restored.exercises.map((item) => item.supersetGroupId), [
        groupId,
        groupId,
      ]);
      expect(
        restored.exercises
            .expand((item) => item.sets)
            .map((set) => set.resolvedSetType),
        everyElement(TrainingSetType.superset),
      );
    });

    test('runs A1 then B1 then rest then A2', () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      await engine.startSession(
        activeSessionId: 'active-advanced',
        draft: pairedDraft(),
      );
      await engine.confirmSession();
      await engine.pairSuperset(
        firstExerciseId: 'bench',
        secondExerciseId: 'row',
      );
      var active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'a1');

      active = await engine.completeSetForFlow(setId: 'a1');
      expect(active.state, TrainingSessionState.activeSet);
      expect(active.currentSetId, 'b1');

      active = await engine.completeSetForFlow(setId: 'b1');
      expect(active.state, TrainingSessionState.resting);
      active = await engine.restFinished();
      active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'a2');
    });

    test('restart after A1 resumes B1 without starting rest', () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      await engine.startSession(
        activeSessionId: 'active-advanced',
        draft: pairedDraft(),
      );
      await engine.confirmSession();
      await engine.pairSuperset(
        firstExerciseId: 'bench',
        secondExerciseId: 'row',
      );
      await engine.startNextAvailableSet();
      await engine.completeSet(setId: 'a1');

      final restored = await TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      ).restore();
      expect(restored?.state, TrainingSessionState.activeSet);
      expect(restored?.currentSetId, 'b1');
      expect(restored?.rest, isNull);
    });

    test(
      'replacement inherits group and clearing preserves completed sets',
      () async {
        final repository = InMemoryTrainingRepository();
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => now,
        );
        await engine.startSession(
          activeSessionId: 'active-advanced',
          draft: pairedDraft(),
        );
        await engine.confirmSession();
        final paired = await engine.pairSuperset(
          firstExerciseId: 'bench',
          secondExerciseId: 'row',
        );
        final groupId = paired.draft.exercises.first.supersetGroupId;
        await engine.startNextAvailableSet();
        await engine.completeSet(setId: 'a1');
        final replaced = await engine.replaceExercise(
          originalExerciseId: 'row',
          replacement: TrainingExercise(
            exerciseId: 'pulldown',
            exerciseName: '高位下拉',
            bodyPart: '背部',
            sets: [
              SetRecord(id: 'r1'),
              SetRecord(id: 'r2'),
            ],
          ),
        );
        expect(replaced.draft.exercises.last.supersetGroupId, groupId);
        expect(
          replaced.draft.exercises.last.sets,
          everyElement(
            isA<SetRecord>().having(
              (set) => set.resolvedSetType,
              'type',
              TrainingSetType.superset,
            ),
          ),
        );

        final cleared = await engine.clearSuperset(exerciseId: 'bench');
        final completedA1 = cleared.draft.exercises.first.sets.first;
        expect(completedA1.completedAt, now);
        expect(completedA1.resolvedSetType, TrainingSetType.superset);
        expect(cleared.draft.exercises.first.supersetGroupId, isNull);
      },
    );
  });

  group('warm-up assistant', () {
    const service = WarmupSuggestionService();
    const barbellBench = ExerciseDefinition(
      id: 'bench',
      name: '杠铃平板卧推',
      bodyPart: '胸部',
      equipment: '自由重量',
      movementPattern: ExerciseMovementPattern.horizontalPush,
    );
    const lateralRaise = ExerciseDefinition(
      id: 'raise',
      name: '哑铃侧平举',
      bodyPart: '肩部',
      equipment: '自由重量',
      movementPattern: ExerciseMovementPattern.shoulderIsolation,
    );

    test('is deterministic, achievable, ordered, and deduplicated', () {
      final first = service.suggest(
        exercise: barbellBench,
        targetWorkingWeight: 80,
      );
      final second = service.suggest(
        exercise: barbellBench,
        targetWorkingWeight: 80,
      );
      expect(first.map((item) => (item.weight, item.reps)), [
        (32.5, 8),
        (47.5, 5),
        (65.0, 3),
      ]);
      expect(
        second.map((item) => (item.weight, item.reps)),
        first.map((item) => (item.weight, item.reps)),
      );
    });

    test('returns no suggestion for low load or isolation exercises', () {
      expect(
        service.suggest(exercise: barbellBench, targetWorkingWeight: 20),
        isEmpty,
      );
      expect(
        service.suggest(exercise: lateralRaise, targetWorkingWeight: 30),
        isEmpty,
      );
    });

    test(
      'inserts before working sets and blocks historical insertion',
      () async {
        final repository = InMemoryTrainingRepository();
        final draft = pairedDraft();
        draft.exercises.removeLast();
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => now,
        );
        await engine.startSession(activeSessionId: 'warmup', draft: draft);
        await engine.confirmSession();
        await engine.startNextAvailableSet();
        final suggestions = service.suggest(
          exercise: barbellBench,
          targetWorkingWeight: 80,
        );
        final inserted = await engine.insertWarmupSuggestions(
          exerciseId: 'bench',
          suggestions: suggestions,
        );
        expect(inserted.currentSetId, startsWith('warmup-bench-warmup-'));
        expect(
          inserted.draft.exercises.single.sets
              .take(3)
              .map((set) => set.resolvedSetType),
          everyElement(TrainingSetType.warmup),
        );
        expect(inserted.draft.exercises.single.sets[3].id, 'a1');

        inserted.draft.exercises.single.sets[3].completedAt = now;
        await repository.saveActiveSession(inserted);
        await expectLater(
          engine.insertWarmupSuggestions(
            exerciseId: 'bench',
            suggestions: suggestions,
          ),
          throwsStateError,
        );
      },
    );
  });

  group('plate calculator', () {
    const service = PlateCalculatorService();

    test('calculates exact 100 kg and 60 kg loads on a 20 kg bar', () {
      final hundred = service.calculate(targetTotalWeight: 100, barWeight: 20);
      final sixty = service.calculate(targetTotalWeight: 60, barWeight: 20);
      expect(hundred.exact, isTrue);
      expect(hundred.platesPerSide, [25, 15]);
      expect(sixty.platesPerSide, [20]);
    });

    test('supports 15 kg and custom bars', () {
      expect(
        service
            .calculate(targetTotalWeight: 55, barWeight: 15)
            .actualTotalWeight,
        55,
      );
      expect(
        service
            .calculate(
              targetTotalWeight: 50,
              barWeight: 10,
              availablePlateSizes: const [10],
            )
            .platesPerSide,
        [10, 10],
      );
    });

    test('returns deterministic nearest lower and upper alternatives', () {
      final result = service.calculate(targetTotalWeight: 83, barWeight: 20);
      expect(result.exact, isFalse);
      expect(result.lowerAlternative?.totalWeight, 82.5);
      expect(result.upperAlternative?.totalWeight, 85);
    });

    test('handles invalid, empty, and restricted plate inputs safely', () {
      expect(
        service.calculate(targetTotalWeight: 10, barWeight: 20).isValid,
        isFalse,
      );
      expect(
        service
            .calculate(
              targetTotalWeight: 60,
              barWeight: 20,
              availablePlateSizes: const [],
            )
            .isValid,
        isFalse,
      );
      final restricted = service.calculate(
        targetTotalWeight: 70,
        barWeight: 20,
        availablePlateSizes: const [10],
      );
      expect(restricted.exact, isFalse);
      expect(restricted.lowerAlternative?.totalWeight, 60);
      expect(restricted.upperAlternative?.totalWeight, 80);
    });
  });
}
