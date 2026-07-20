import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/training_draft_factory.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/services/training_template_store.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';
import 'package:goat_app/repositories/local_training_repository.dart';
import 'package:goat_app/repositories/training_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bench = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃平板卧推',
  );
  final row = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃俯身划船',
  );
  final triceps = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '绳索下压',
  );
  final now = DateTime.utc(2026, 7, 20, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  TrainingSession draftFrom(
    TrainingTemplate template, {
    String id = 'delta-session',
    int setsPerExercise = 1,
  }) {
    return const TrainingDraftFactory().create(
      id: id,
      name: template.name,
      date: '2026-07-20',
      exercises: template.resolveExercises(exerciseCatalog),
      setsPerExercise: setsPerExercise,
    );
  }

  test(
    'plan launch creates only an ordered active snapshot with stable metadata',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'user_a',
      );
      final template = TrainingTemplate(
        id: 'upper-a',
        name: '胸加三头',
        exerciseIds: [triceps.id, bench.id, row.id, bench.id],
      );
      await store.save(template);
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );

      await engine.startSession(
        activeSessionId: 'active-delta',
        draft: draftFrom(template),
      );

      final active = await repository.loadActiveSession();
      expect(await repository.listCompletedSessions(), isEmpty);
      expect(active?.draft.exercises, hasLength(3));
      expect(active?.draft.exercises.map((exercise) => exercise.exerciseId), [
        triceps.id,
        bench.id,
        row.id,
      ]);
      expect(active?.draft.exercises.map((exercise) => exercise.orderIndex), [
        0,
        1,
        2,
      ]);
      for (final exercise in active!.draft.exercises) {
        final definition = exerciseCatalog.firstWhere(
          (candidate) => candidate.id == exercise.exerciseId,
        );
        expect(exercise.exerciseName, definition.name);
        expect(exercise.bodyPart, definition.bodyPart);
      }

      await store.save(
        TrainingTemplate(
          id: template.id,
          name: '已编辑方案',
          exerciseIds: [bench.id],
        ),
      );
      final unchangedActive = await repository.loadActiveSession();
      expect(unchangedActive?.draft.name, '胸加三头');
      expect(unchangedActive?.draft.exercises, hasLength(3));
    },
  );

  test(
    'template CRUD keeps stable ID, order and user namespace isolation',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final userA = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'user_a',
      );
      final userB = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'user_b',
      );
      final created = TrainingTemplate(
        id: 'back-a',
        name: '背部 A',
        exerciseIds: [row.id, bench.id],
      );
      await userA.save(created);

      expect(userB.load(), isEmpty);
      expect(
        TrainingTemplateStore(
          preferences: preferences,
          namespace: 'user_a',
        ).load().single.exerciseIds,
        [row.id, bench.id],
      );

      final edited = TrainingTemplate(
        id: created.id,
        name: '背部 B',
        exerciseIds: [bench.id, row.id],
      );
      await userA.save(edited);
      expect(userA.load(), hasLength(1));
      expect(userA.load().single.id, created.id);
      expect(userA.load().single.exerciseIds, [bench.id, row.id]);

      await userA.delete(created.id);
      expect(userA.load(), isEmpty);
      expect(userB.load(), isEmpty);
    },
  );

  test('deleting a plan does not delete completed history', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = TrainingTemplateStore(
      preferences: preferences,
      namespace: 'history_user',
    );
    final template = TrainingTemplate(
      id: 'history-plan',
      name: '历史隔离方案',
      exerciseIds: [bench.id, row.id],
    );
    await store.save(template);
    final repository = InMemoryTrainingRepository();
    final engine = TrainingSessionEngine(
      repository: repository,
      clock: () => now,
    );
    final draft = draftFrom(template, id: 'history-session');
    await engine.startSession(activeSessionId: 'active-history', draft: draft);
    await engine.confirmSession();
    await engine.startNextAvailableSet();
    var active = await engine.completeSetForFlow(
      setId: draft.exercises.first.sets.single.id!,
    );
    expect(active.state, TrainingSessionState.resting);
    await engine.skipRest();
    await engine.startNextAvailableSet();
    active = await engine.completeSetForFlow(
      setId: draft.exercises.last.sets.single.id!,
    );
    expect(active.state, TrainingSessionState.setCompleted);
    await engine.finishSession();

    await store.delete(template.id);
    expect(store.load(), isEmpty);
    expect(await repository.loadActiveSession(), isNull);
    final history = await repository.listCompletedSessions();
    expect(history, hasLength(1));
    expect(history.single.exercises.map((exercise) => exercise.exerciseId), [
      bench.id,
      row.id,
    ]);
  });

  test(
    'template-based rest and active session recover after app restart',
    () async {
      final storage = await LocalStorageService.create();
      final preferences = storage.prefs;
      final store = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'restart_user',
      );
      final template = TrainingTemplate(
        id: 'restart-plan',
        name: '重启方案',
        exerciseIds: [bench.id],
      );
      await store.save(template);
      var repository = LocalTrainingRepository(
        storage: storage,
        namespace: 'restart_user',
        clock: () => now,
      );
      var engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      final draft = draftFrom(
        template,
        id: 'restart-session',
        setsPerExercise: 2,
      );
      await engine.startSession(
        activeSessionId: 'active-restart',
        draft: draft,
      );
      await engine.confirmSession();
      await engine.startNextAvailableSet();
      await engine.completeSetForFlow(
        setId: draft.exercises.single.sets.first.id!,
      );

      final restartedStorage = await LocalStorageService.create();
      repository = LocalTrainingRepository(
        storage: restartedStorage,
        namespace: 'restart_user',
        clock: () => now.add(const Duration(seconds: 15)),
      );
      engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now.add(const Duration(seconds: 15)),
      );
      final restored = await engine.restore();
      expect(restored?.id, 'active-restart');
      expect(restored?.state, TrainingSessionState.resting);
      expect(restored?.draft.exercises.single.exerciseId, bench.id);
      expect(await repository.listCompletedSessions(), isEmpty);
      expect(
        TrainingTemplateStore(
          preferences: restartedStorage.prefs,
          namespace: 'restart_user',
        ).load().single.id,
        template.id,
      );
    },
  );

  test(
    'new selector metadata remains compatible with stable-ID last performance',
    () async {
      final historical = TrainingSession(
        id: 'old-session',
        name: '历史训练',
        date: '2026-07-19',
        exercises: [
          TrainingExercise(
            exerciseId: bench.id,
            exerciseName: '旧显示名称',
            bodyPart: bench.bodyPart,
            sets: [
              SetRecord(
                id: 'old-set',
                weight: 80,
                reps: 6,
                setType: TrainingSetType.working,
              ),
            ],
          ),
        ],
      );
      final repository = InMemoryTrainingRepository(
        completedSessions: [historical],
      );
      final selectedDraft = const TrainingDraftFactory().create(
        id: 'new-session',
        name: '新训练',
        date: '2026-07-20',
        exercises: [bench],
        setsPerExercise: 1,
      );
      final performance = await repository.findLastPerformance(
        ExerciseReference(
          exerciseId: selectedDraft.exercises.single.exerciseId,
          exerciseName: selectedDraft.exercises.single.exerciseName,
        ),
        setOrdinal: 0,
      );

      expect(performance?.matchedByStableId, isTrue);
      expect(performance?.set.weight, 80);
      expect(performance?.set.reps, 6);
    },
  );
}
