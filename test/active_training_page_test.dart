import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/active_training_session.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/pages/active_training_page.dart';
import 'package:goat_app/features/training/pages/training_completion_page.dart';
import 'package:goat_app/features/training/services/exercise_replacement_service.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/widgets/active_training_session_card.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  final now = DateTime(2026, 7, 18, 10);
  final bench = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃平板卧推',
  );

  TrainingSession draft() => TrainingSession(
    id: 'session-fast',
    name: '自主训练',
    date: '2026-07-18',
    exercises: [
      TrainingExercise(
        exerciseId: bench.id,
        exerciseName: bench.name,
        bodyPart: bench.bodyPart,
        sets: List.generate(
          2,
          (index) => SetRecord(
            id: 'set-${index + 1}',
            setType: TrainingSetType.working,
          ),
        ),
      ),
    ],
  );

  TrainingSession history() => TrainingSession(
    id: 'session-history',
    name: '历史训练',
    date: '2026-07-17',
    exercises: [
      TrainingExercise(
        exerciseId: bench.id,
        exerciseName: bench.name,
        bodyPart: bench.bodyPart,
        sets: [
          SetRecord(
            id: 'history-set',
            weight: 80,
            reps: 8,
            rir: 2,
            setType: TrainingSetType.working,
            completedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
    ],
  );

  Future<
    ({
      InMemoryTrainingRepository repository,
      TrainingSessionEngine engine,
      ActiveTrainingSession active,
    })
  >
  createSession({bool withHistory = true}) async {
    final repository = InMemoryTrainingRepository(
      completedSessions: withHistory ? [history()] : const [],
    );
    final engine = TrainingSessionEngine(
      repository: repository,
      clock: () => now,
    );
    final active = await engine.startSession(
      activeSessionId: 'active-fast',
      draft: draft(),
    );
    return (repository: repository, engine: engine, active: active);
  }

  Widget page({
    required ActiveTrainingSession active,
    required TrainingSessionEngine engine,
    required InMemoryTrainingRepository repository,
  }) => MaterialApp(
    home: ActiveTrainingPage(
      initialSession: active,
      engine: engine,
      repository: repository,
      catalog: exerciseCatalog,
      onSessionChanged: (_) {},
      onFinished: (_) async {},
      clock: () => now,
    ),
  );

  testWidgets('autofills last performance and persists fast set controls', (
    tester,
  ) async {
    final setup = await createSession();
    await tester.pumpWidget(
      page(
        active: setup.active,
        engine: setup.engine,
        repository: setup.repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-training-page')), findsOneWidget);
    expect(find.text('80.0 kg'), findsOneWidget);
    expect(find.textContaining('沿用上次'), findsOneWidget);

    await tester.tap(find.byKey(const Key('training-weight-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-reps-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-rir-1')));
    await tester.pumpAndSettle();

    final active = await setup.repository.loadActiveSession();
    final set = active!.draft.exercises.first.sets.first;
    expect(set.weight, 82.5);
    expect(set.reps, 9);
    expect(set.rir, 1);

    await tester.tap(find.byKey(const Key('training-complete-set')));
    await tester.pump();
    final completed = await setup.repository.loadActiveSession();
    expect(completed?.state, TrainingSessionState.resting);
    expect(completed?.draft.exercises.first.sets.first.completedAt, now);
    expect(find.text('下一组'), findsOneWidget);
  });

  testWidgets('replaces the current exercise and activates its first set', (
    tester,
  ) async {
    final setup = await createSession(withHistory: false);
    await tester.pumpWidget(
      page(
        active: setup.active,
        engine: setup.engine,
        repository: setup.repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('training-complete-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换动作'));
    await tester.pumpAndSettle();

    final candidate = const ExerciseReplacementService()
        .rank(original: bench, catalog: exerciseCatalog)
        .first
        .exercise;
    await tester.tap(find.byKey(Key('replacement-${candidate.id}')));
    await tester.pumpAndSettle();

    final active = await setup.repository.loadActiveSession();
    expect(active?.currentExerciseId, candidate.id);
    expect(active?.currentSetId, isNotNull);
    expect(active?.state, TrainingSessionState.activeSet);
    expect(
      active?.draft.exercises.first.status,
      TrainingExerciseStatus.replaced,
    );
    expect(find.text(candidate.name), findsOneWidget);
    expect(find.text('动作 1 / 1'), findsOneWidget);
    expect(find.text('完成本组'), findsOneWidget);
  });

  testWidgets('completed set enters rest and skip starts the next set', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final setup = await createSession(withHistory: false);
    await tester.pumpWidget(
      page(
        active: setup.active,
        engine: setup.engine,
        repository: setup.repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('training-complete-set')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest-timer-card')), findsOneWidget);
    expect(
      (await setup.repository.loadActiveSession())?.state,
      TrainingSessionState.resting,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('rest-skip')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('rest-skip')));
    await tester.pumpAndSettle();
    expect(
      (await setup.repository.loadActiveSession())?.state,
      TrainingSessionState.readyForNextSet,
    );
    await tester.tap(find.byKey(const Key('training-start-next-set')));
    await tester.pumpAndSettle();
    final next = await setup.repository.loadActiveSession();
    expect(next?.state, TrainingSessionState.activeSet);
    expect(next?.currentSetId, 'set-2');
  });

  testWidgets('rest timer reaches ready state from absolute time', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    var clock = now;
    final setup = await createSession(withHistory: false);
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTrainingPage(
          initialSession: setup.active,
          engine: TrainingSessionEngine(
            repository: setup.repository,
            clock: () => clock,
          ),
          repository: setup.repository,
          catalog: exerciseCatalog,
          clock: () => clock,
          onSessionChanged: (_) {},
          onFinished: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-complete-set')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest-timer-card')), findsOneWidget);

    clock = now.add(const Duration(seconds: 90));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      (await setup.repository.loadActiveSession())?.state,
      TrainingSessionState.readyForNextSet,
    );
    expect(find.text('休息已结束'), findsOneWidget);
  });

  testWidgets('rest duration sheet applies preset to timer and current set', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final setup = await createSession(withHistory: false);
    await tester.pumpWidget(
      page(
        active: setup.active,
        engine: setup.engine,
        repository: setup.repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-complete-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rest-duration-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120 秒'));
    await tester.pumpAndSettle();

    final active = await setup.repository.loadActiveSession();
    expect(active?.rest?.restDurationSeconds, 120);
    expect(active?.draft.exercises.single.sets.first.restSeconds, 120);
  });

  testWidgets(
    'resume card and completion screen expose their primary actions',
    (tester) async {
      final setup = await createSession(withHistory: false);
      var resumed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveTrainingSessionCard(
              session: setup.active,
              onTap: () => resumed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('training-resume-card')));
      expect(resumed, isTrue);

      final completed = history();
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingCompletionPage(
            session: completed,
            durationMinutes: 42,
            onDone: () => done = true,
          ),
        ),
      );
      expect(find.text('GOAL'), findsOneWidget);
      expect(find.text('42 分钟'), findsOneWidget);
      expect(find.text('1 组'), findsOneWidget);
      await tester.tap(find.byKey(const Key('training-completion-done')));
      expect(done, isTrue);
    },
  );
}
