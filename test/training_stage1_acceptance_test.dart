import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/pages/active_training_page.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';
import 'package:goat_app/repositories/local_training_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var now = DateTime.utc(2026, 7, 18, 14);
  final bench = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃平板卧推',
  );
  final row = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃俯身划船',
  );

  TrainingSession fullDraft() => TrainingSession(
    id: 'stage1-full-session',
    name: 'Stage 1 验收训练',
    date: '2026-07-18',
    exercises: [
      TrainingExercise(
        exerciseId: bench.id,
        exerciseName: bench.name,
        bodyPart: bench.bodyPart,
        orderIndex: 0,
        sets: [
          SetRecord(id: 'bench-1', setType: TrainingSetType.working),
          SetRecord(id: 'bench-2', setType: TrainingSetType.working),
        ],
      ),
      TrainingExercise(
        exerciseId: row.id,
        exerciseName: row.name,
        bodyPart: row.bodyPart,
        orderIndex: 1,
        sets: [SetRecord(id: 'row-1', setType: TrainingSetType.working)],
      ),
    ],
  );

  setUp(() {
    now = DateTime.utc(2026, 7, 18, 14);
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'full engine flow persists edits, rest, next exercise and finish once',
    () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      await engine.startSession(
        activeSessionId: 'active-stage1-full',
        draft: fullDraft(),
      );
      await engine.confirmSession();
      var active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'bench-1');
      expect(await repository.listCompletedSessions(), isEmpty);

      active = await engine.updateSet(
        setId: 'bench-1',
        weight: 67.5,
        reps: 9,
        rir: 2,
        setType: TrainingSetType.working,
      );
      expect(active.draft.exercises.first.sets.first.weight, 67.5);
      expect(active.draft.exercises.first.sets.first.rir, 2);

      active = await engine.completeSetForFlow(setId: 'bench-1');
      expect(active.state, TrainingSessionState.resting);
      expect(active.draft.exercises.first.sets.first.completedAt, now);
      active = await engine.updateRestDuration(durationSeconds: 120);
      expect(active.rest?.restStartedAt, now);
      expect(
        active.rest?.restExpectedEndAt,
        now.add(const Duration(seconds: 120)),
      );
      active = await engine.skipRest();
      active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'bench-2');

      active = await engine.completeSetForFlow(setId: 'bench-2');
      expect(active.state, TrainingSessionState.resting);
      active = await engine.restFinished();
      active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'row-1');

      active = await engine.updateSet(
        setId: 'row-1',
        weight: 60,
        reps: 10,
        reachedFailure: true,
      );
      active = await engine.completeSetForFlow(setId: 'row-1');
      expect(active.state, TrainingSessionState.setCompleted);
      expect(active.rest, isNull);

      final completed = await engine.finishSession();
      expect(await repository.loadActiveSession(), isNull);
      final history = await repository.listCompletedSessions();
      expect(history, hasLength(1));
      expect(history.single.id, completed.id);
      expect(history.single.exercises, hasLength(2));
      expect(history.single.exercises.last.sets.single.reachedFailure, isTrue);
      await expectLater(engine.finishSession(), throwsStateError);
      expect(await repository.listCompletedSessions(), hasLength(1));
    },
  );

  test(
    'local repository restores absolute rest then clears after finish',
    () async {
      final storage = await LocalStorageService.create();
      var repository = LocalTrainingRepository(
        storage: storage,
        namespace: 'stage1-final-recovery',
        clock: () => now,
      );
      var engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      final draft = fullDraft()..exercises.removeLast();
      await engine.startSession(
        activeSessionId: 'active-stage1-recovery',
        draft: draft,
      );
      await engine.confirmSession();
      await engine.startNextAvailableSet();
      await engine.completeSetForFlow(setId: 'bench-1');

      now = now.add(const Duration(seconds: 30));
      repository = LocalTrainingRepository(
        storage: await LocalStorageService.create(),
        namespace: 'stage1-final-recovery',
        clock: () => now,
      );
      engine = TrainingSessionEngine(repository: repository, clock: () => now);
      var restored = await engine.restore();
      expect(restored?.state, TrainingSessionState.resting);
      expect(restored?.rest?.remainingAt(now).inSeconds, 60);
      expect(restored?.currentSetId, 'bench-1');
      expect(
        restored?.draft.exercises.single.sets.first.completedAt,
        isNotNull,
      );

      now = now.add(const Duration(seconds: 61));
      restored = await engine.restore();
      expect(restored?.state, TrainingSessionState.readyForNextSet);
      restored = await engine.startNextAvailableSet();
      expect(restored.currentSetId, 'bench-2');
      await engine.completeSetForFlow(setId: 'bench-2');
      await engine.finishSession();

      final afterRestart = LocalTrainingRepository(
        storage: await LocalStorageService.create(),
        namespace: 'stage1-final-recovery',
        clock: () => now,
      );
      expect(await afterRestart.loadActiveSession(), isNull);
      expect(await afterRestart.listCompletedSessions(), hasLength(1));
    },
  );

  test(
    'superset replacement during rest preserves round and old history',
    () async {
      final repository = InMemoryTrainingRepository();
      final engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      final draft = fullDraft();
      draft.exercises.last.sets.add(
        SetRecord(id: 'row-2', setType: TrainingSetType.working),
      );
      await engine.startSession(
        activeSessionId: 'active-superset-replacement',
        draft: draft,
      );
      await engine.confirmSession();
      final paired = await engine.pairSuperset(
        firstExerciseId: bench.id,
        secondExerciseId: row.id,
      );
      final groupId = paired.draft.exercises.first.supersetGroupId;
      await engine.startNextAvailableSet();
      var active = await engine.completeSetForFlow(setId: 'bench-1');
      expect(active.currentSetId, 'row-1');
      active = await engine.completeSetForFlow(setId: 'row-1');
      expect(active.state, TrainingSessionState.resting);

      active = await engine.replaceExercise(
        originalExerciseId: row.id,
        replacement: TrainingExercise(
          exerciseId: 'lat-pulldown-replacement',
          exerciseName: '高位下拉',
          bodyPart: '背部',
          sets: [
            SetRecord(id: 'replacement-1'),
            SetRecord(id: 'replacement-2'),
          ],
        ),
      );
      expect(active.state, TrainingSessionState.resting);
      expect(active.rest, isNotNull);
      expect(active.currentSetId, 'replacement-1');
      expect(active.draft.exercises[1].sets.first.completedAt, now);
      expect(active.draft.exercises.last.supersetGroupId, groupId);
      expect(
        active.draft.exercises.last.sets.first.replacementPlaceholder,
        isTrue,
      );

      active = await engine.restFinished();
      active = await engine.startNextAvailableSet();
      expect(active.currentSetId, 'bench-2');
      active = await engine.completeSetForFlow(setId: 'bench-2');
      expect(active.currentSetId, 'replacement-2');
      active = await engine.completeSetForFlow(setId: 'replacement-2');
      expect(active.state, TrainingSessionState.setCompleted);
      expect(active.rest, isNull);

      final completed = await engine.finishSession();
      final oldPartner = completed.exercises.firstWhere(
        (exercise) => exercise.exerciseId == row.id,
      );
      final newPartner = completed.exercises.firstWhere(
        (exercise) => exercise.exerciseId == 'lat-pulldown-replacement',
      );
      expect(oldPartner.status, TrainingExerciseStatus.replaced);
      expect(oldPartner.sets.map((set) => set.id), ['row-1']);
      expect(newPartner.substitutedFromExerciseId, row.id);
      expect(newPartner.supersetGroupId, groupId);
      expect(newPartner.sets.map((set) => set.id), ['replacement-2']);
    },
  );

  test('old and partial training JSON stays readable without migration', () {
    final session = TrainingSession.fromJson({
      'id': 'legacy-stage1',
      'name': '旧训练',
      'date': '2025-01-01',
      'exercises': [
        {
          'exerciseName': '卧推',
          'bodyPart': '胸部',
          'sets': [
            {'weight': 20, 'reps': 10, 'type': '热身'},
            {'weight': 60, 'reps': 8, 'type': '正常'},
            {'weight': 65, 'reps': 5, 'type': '突破'},
            {'weight': 0, 'reps': 0, 'type': '未知值'},
          ],
        },
      ],
    });

    expect(session.exercises.single.exerciseId, isNull);
    expect(session.exercises.single.supersetGroupId, isNull);
    expect(session.exercises.single.sets.map((set) => set.resolvedSetType), [
      TrainingSetType.warmup,
      TrainingSetType.working,
      TrainingSetType.working,
      TrainingSetType.working,
    ]);
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets(
      'Stage 1 tools do not overflow at ${size.width}x${size.height}',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(size);
        final history = fullDraft();
        history.date = '2026-07-17';
        history.exercises.first.sets.first
          ..weight = 80
          ..reps = 8
          ..completedAt = now;
        final repository = InMemoryTrainingRepository(
          completedSessions: [history],
        );
        final engine = TrainingSessionEngine(
          repository: repository,
          clock: () => now,
        );
        final active = await engine.startSession(
          activeSessionId: 'responsive-${size.width}',
          draft: fullDraft(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ActiveTrainingPage(
              initialSession: active,
              engine: engine,
              repository: repository,
              catalog: exerciseCatalog,
              clock: () => now,
              onSessionChanged: (_) {},
              onFinished: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('training-set-type-entry')));
        await tester.pumpAndSettle();
        expect(find.text('组类型'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('超级组').last);
        await tester.pumpAndSettle();
        expect(find.text('选择搭配动作'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('热身组建议'));
        await tester.pumpAndSettle();
        expect(find.text('加入本次训练'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('杠铃片计算器'));
        await tester.pumpAndSettle();
        expect(find.text('应用到当前组'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
