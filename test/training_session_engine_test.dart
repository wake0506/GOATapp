import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/active_training_session.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/domain/training_session_state_machine.dart';
import 'package:goat_app/features/training/services/exercise_replacement_service.dart';
import 'package:goat_app/features/training/services/last_performance_resolver.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';
import 'package:goat_app/repositories/local_training_repository.dart';
import 'package:goat_app/repositories/training_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 7, 18, 10);

  TrainingSession draft({String id = 'session-1'}) => TrainingSession(
    id: id,
    name: 'Push',
    date: '2026-07-18',
    exercises: [
      TrainingExercise(
        exerciseId: 'bench_press_barbell',
        exerciseName: '杠铃平板卧推',
        bodyPart: '胸部',
        sets: [SetRecord(id: 'set-1', weight: 60, reps: 8)],
      ),
    ],
  );

  ActiveTrainingSession active({
    TrainingSessionState state = TrainingSessionState.preparing,
    RestState? rest,
    TrainingSessionState? resumeState,
  }) => ActiveTrainingSession(
    id: 'active-1',
    draft: draft(),
    state: state,
    startedAt: now,
    updatedAt: now,
    rest: rest,
    resumeState: resumeState,
  );

  group('model compatibility', () {
    test('loads old training JSON without Stage 1A fields', () {
      final session = TrainingSession.fromJson({
        'id': 'old',
        'name': '旧训练',
        'date': '2025-01-01',
        'exercises': [
          {
            'exerciseName': '卧推',
            'bodyPart': '胸部',
            'sets': [
              {'weight': 50, 'reps': 8, 'type': '正常'},
            ],
          },
        ],
      });

      final set = session.exercises.single.sets.single;
      expect(session.exercises.single.exerciseId, isNull);
      expect(set.id, isNull);
      expect(set.resolvedSetType, TrainingSetType.working);
      expect(set.rir, isNull);
    });

    test('maps old Chinese types and safely drops invalid metrics', () {
      final warmup = SetRecord.fromJson({'type': '热身'});
      final normal = SetRecord.fromJson({'type': '正常'});
      final breakthrough = SetRecord.fromJson({'type': '突破'});
      final unknown = SetRecord.fromJson({'type': '未知', 'rir': 4, 'rpe': 11});

      expect(warmup.resolvedSetType, TrainingSetType.warmup);
      expect(normal.resolvedSetType, TrainingSetType.working);
      expect(breakthrough.resolvedSetType, TrainingSetType.working);
      expect(breakthrough.isLegacyBreakthrough, isTrue);
      expect(unknown.resolvedSetType, TrainingSetType.working);
      expect(unknown.rir, isNull);
      expect(unknown.rpe, isNull);
    });
  });

  group('state machine', () {
    const machine = TrainingSessionStateMachine();

    test('accepts the core transition path', () {
      var state = TrainingSessionState.idle;
      for (final event in [
        TrainingSessionEvent.startSession,
        TrainingSessionEvent.confirmSession,
        TrainingSessionEvent.startSet,
        TrainingSessionEvent.completeSet,
        TrainingSessionEvent.startRest,
        TrainingSessionEvent.restFinished,
      ]) {
        final result = machine.transition(state: state, event: event);
        expect(result.isAccepted, isTrue);
        state = result.to;
      }
      expect(state, TrainingSessionState.readyForNextSet);
    });

    test('rejects invalid transitions without changing state', () {
      final result = machine.transition(
        state: TrainingSessionState.idle,
        event: TrainingSessionEvent.completeSet,
      );
      expect(result.isAccepted, isFalse);
      expect(result.to, TrainingSessionState.idle);
      expect(result.reason, isNotEmpty);
    });
  });

  group('local repository and engine', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves, reloads, and clears an active session', () async {
      final storage = await LocalStorageService.create();
      final repository = LocalTrainingRepository(
        storage: storage,
        namespace: 'stage1a',
      );
      await repository.saveActiveSession(active());

      final reloadedStorage = await LocalStorageService.create();
      final reloaded = LocalTrainingRepository(
        storage: reloadedStorage,
        namespace: 'stage1a',
      );
      expect((await reloaded.loadActiveSession())?.id, 'active-1');

      await reloaded.clearActiveSession();
      expect(await reloaded.loadActiveSession(), isNull);
    });

    test('persists a completed set immediately and finishes once', () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      await engine.startSession(activeSessionId: 'active-1', draft: draft());
      await engine.confirmSession();
      await engine.startSet(exerciseId: 'bench_press_barbell', setId: 'set-1');
      await engine.completeSet(setId: 'set-1');

      final persisted = await repository.loadActiveSession();
      expect(persisted?.state, TrainingSessionState.setCompleted);
      expect(persisted?.draft.exercises.single.sets.single.completedAt, now);

      await engine.finishSession();
      await expectLater(engine.finishSession(), throwsStateError);
      expect(await repository.loadActiveSession(), isNull);
      expect((await repository.listCompletedSessions()).length, 1);
    });

    test(
      'a new set inherits weight and reps from the previous completed set',
      () async {
        final repository = InMemoryTrainingRepository();
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => now,
        );
        final session = draft();
        session.exercises.single.sets.add(SetRecord(id: 'set-2'));
        await engine.startSession(
          activeSessionId: 'active-copy',
          draft: session,
        );
        await engine.confirmSession();
        await engine.startSet(
          exerciseId: 'bench_press_barbell',
          setId: 'set-1',
        );
        await engine.updateSet(setId: 'set-1', weight: 72.5, reps: 9);
        await engine.completeSet(setId: 'set-1');
        await engine.nextSet();

        final next = await engine.startSet(
          exerciseId: 'bench_press_barbell',
          setId: 'set-2',
        );

        expect(next.draft.exercises.single.sets[1].weight, 72.5);
        expect(next.draft.exercises.single.sets[1].reps, 9);
      },
    );

    test(
      'rest recovery uses absolute time and expires into ready state',
      () async {
        final storage = await LocalStorageService.create();
        final clock = DateTime.utc(2026, 7, 18, 10, 1, 10);
        final repository = LocalTrainingRepository(
          storage: storage,
          namespace: 'rest',
          clock: () => clock,
        );
        await repository.saveActiveSession(
          active(
            state: TrainingSessionState.resting,
            rest: RestState(
              setId: 'set-1',
              restStartedAt: now,
              restDurationSeconds: 90,
            ),
          ),
        );

        final restored = await repository.loadActiveSession();
        expect(restored?.rest?.remainingAt(clock).inSeconds, 20);
        expect(restored?.state, TrainingSessionState.resting);

        final expiredRepository = LocalTrainingRepository(
          storage: storage,
          namespace: 'rest',
          clock: () => now.add(const Duration(minutes: 2)),
        );
        expect(
          (await expiredRepository.loadActiveSession())?.state,
          TrainingSessionState.readyForNextSet,
        );
      },
    );

    test('pause resumes its saved state', () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      await engine.startSession(activeSessionId: 'active-1', draft: draft());
      await engine.confirmSession();
      await engine.pause();
      expect(
        (await repository.loadActiveSession())?.resumeState,
        TrainingSessionState.readyForNextSet,
      );
      await engine.resume();
      expect(
        (await repository.loadActiveSession())?.state,
        TrainingSessionState.readyForNextSet,
      );
    });

    test('rest duration can be changed from the original start time', () async {
      var clock = now.add(const Duration(seconds: 30));
      final repository = InMemoryTrainingRepository(
        activeSession: active(
          state: TrainingSessionState.resting,
          rest: RestState(
            setId: 'set-1',
            restStartedAt: now,
            restDurationSeconds: 90,
          ),
        ),
      );
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => clock,
      );

      final updated = await engine.updateRestDuration(durationSeconds: 120);
      expect(updated.rest?.restDurationSeconds, 120);
      expect(updated.rest?.remainingAt(clock).inSeconds, 90);

      clock = now.add(const Duration(seconds: 121));
      final expired = await engine.restore();
      expect(expired?.state, TrainingSessionState.readyForNextSet);
      expect(expired?.rest, isNull);
    });

    test('exercise rest duration updates every set in that exercise', () async {
      final session = active(
        state: TrainingSessionState.resting,
        rest: RestState(
          setId: 'set-1',
          restStartedAt: now,
          restDurationSeconds: 90,
        ),
      );
      session.draft.exercises.single.sets.addAll([
        SetRecord(id: 'set-2'),
        SetRecord(id: 'set-3'),
      ]);
      final repository = InMemoryTrainingRepository(activeSession: session);
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );

      final updated = await engine.updateExerciseRestDuration(
        exerciseId: 'bench_press_barbell',
        durationSeconds: 150,
      );

      expect(
        updated.draft.exercises.single.sets.map((set) => set.restSeconds),
        everyElement(150),
      );
    });

    test(
      'shortening an already elapsed rest immediately finishes it',
      () async {
        final clock = now.add(const Duration(seconds: 80));
        final repository = InMemoryTrainingRepository(
          activeSession: active(
            state: TrainingSessionState.resting,
            rest: RestState(
              setId: 'set-1',
              restStartedAt: now,
              restDurationSeconds: 120,
            ),
          ),
        );
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => clock,
        );

        final updated = await engine.updateRestDuration(durationSeconds: 60);
        expect(updated.state, TrainingSessionState.readyForNextSet);
        expect(updated.rest, isNull);
      },
    );

    test(
      'completeSetAndStartRest persists both completion and rest state',
      () async {
        final repository = InMemoryTrainingRepository();
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => now,
        );
        await engine.startSession(activeSessionId: 'active-1', draft: draft());
        await engine.confirmSession();
        await engine.startSet(
          exerciseId: 'bench_press_barbell',
          setId: 'set-1',
        );

        final resting = await engine.completeSetAndStartRest(
          setId: 'set-1',
          durationSeconds: 60,
        );
        expect(resting.state, TrainingSessionState.resting);
        expect(
          resting.rest?.restExpectedEndAt,
          now.add(const Duration(seconds: 60)),
        );
        expect(resting.draft.exercises.single.sets.single.completedAt, now);
      },
    );
  });

  group('last performance', () {
    test('uses stable ID, ordinal, then latest working set only', () {
      final older = draft(id: 'older');
      older.date = '2026-07-01';
      older.exercises.single.sets.addAll([
        SetRecord(id: 'old-warmup', type: '热身', weight: 40, reps: 10),
        SetRecord(
          id: 'old-second',
          setType: TrainingSetType.working,
          weight: 70,
          reps: 6,
        ),
      ]);
      final latest = draft(id: 'latest');
      latest.date = '2026-07-10';
      latest.exercises.single.sets.single.setType = TrainingSetType.warmup;

      final resolver = LastPerformanceResolver();
      final result = resolver.resolve(
        sessions: [older, latest],
        exercise: const ExerciseReference(
          exerciseId: 'bench_press_barbell',
          exerciseName: '不同显示名',
        ),
        setOrdinal: 1,
      );
      expect(result?.set.id, 'old-second');
      expect(result?.matchedByStableId, isTrue);
    });

    test(
      'uses exact normalized name only for legacy data and excludes non-working sets',
      () {
        final legacy = TrainingSession(
          id: 'legacy',
          name: 'legacy',
          date: '2026-07-10',
          exercises: [
            TrainingExercise(
              exerciseName: ' 卧推 ',
              bodyPart: '胸部',
              sets: [
                SetRecord(type: '热身', weight: 20, reps: 12),
                SetRecord(type: '突破', weight: 90, reps: 1),
                SetRecord(type: '正常', weight: 60, reps: 8),
              ],
            ),
          ],
        );
        final result = const LastPerformanceResolver().resolve(
          sessions: [legacy],
          exercise: const ExerciseReference(exerciseName: '卧推'),
        );
        expect(result?.set.weight, 60);
        expect(result?.matchedByStableId, isFalse);
      },
    );
  });

  group('exercise replacement', () {
    const original = ExerciseDefinition(
      id: 'bench_press_barbell',
      name: '杠铃平板卧推',
      bodyPart: '胸部',
      equipment: '自由重量',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps'],
      movementPattern: ExerciseMovementPattern.horizontalPush,
    );

    test('applies hard filters and deterministic structured ranking', () {
      const samePattern = ExerciseDefinition(
        id: 'bench_press_dumbbell',
        name: '哑铃平板卧推',
        bodyPart: '胸部',
        equipment: '自由重量',
        primaryMuscles: ['chest'],
        secondaryMuscles: ['triceps'],
        movementPattern: ExerciseMovementPattern.horizontalPush,
      );
      const otherPattern = ExerciseDefinition(
        id: 'chest_fly_machine',
        name: '夹胸',
        bodyPart: '胸部',
        equipment: '器械',
        primaryMuscles: ['chest'],
        movementPattern: ExerciseMovementPattern.other,
      );
      final ranked = const ExerciseReplacementService().rank(
        original: original,
        catalog: [original, otherPattern, samePattern],
        constraints: const ExerciseConstraints(unavailableEquipment: {'器械'}),
      );
      expect(ranked.single.exercise.id, 'bench_press_dumbbell');
      expect(ranked.single.isLowConfidence, isFalse);
    });

    test(
      'uses labeled body-part fallback when structured metadata is absent',
      () {
        const fallback = ExerciseDefinition(
          id: 'legacy_chest',
          name: '俯卧撑',
          bodyPart: '胸部',
          equipment: '徒手',
          primaryMuscles: ['core'],
        );
        final ranked = const ExerciseReplacementService().rank(
          original: original,
          catalog: [fallback],
        );
        expect(ranked.single.isLowConfidence, isTrue);
      },
    );

    test('every built-in catalog entry resolves to a stable ID', () {
      expect(exerciseCatalog, isNotEmpty);
      expect(
        exerciseCatalog.map((exercise) => exercise.id),
        everyElement(isNotEmpty),
      );
    });
  });
}
