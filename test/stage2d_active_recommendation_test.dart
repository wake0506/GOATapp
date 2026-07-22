import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/active_training_session.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/pages/active_training_page.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  final now = DateTime(2026, 7, 20, 10);

  ActiveTrainingSession active() {
    final completed = SetRecord(
      id: 'vertical-set',
      reps: 8,
      setType: TrainingSetType.working,
      completedAt: now,
    );
    return ActiveTrainingSession(
      id: 'active-back',
      draft: TrainingSession(
        id: 'back-day',
        name: 'Back Day',
        date: '2026-07-20',
        exercises: [
          TrainingExercise(
            exerciseId: 'lat_pulldown',
            exerciseName: '高位下拉',
            bodyPart: '背部',
            sets: [completed],
          ),
          TrainingExercise(
            exerciseId: 'pull_up',
            exerciseName: '引体向上',
            bodyPart: '背部',
            sets: [
              SetRecord(
                id: 'pull-set',
                reps: 8,
                setType: TrainingSetType.working,
                completedAt: now,
              ),
            ],
          ),
          TrainingExercise(
            exerciseId: 'seated_cable_row',
            exerciseName: '坐姿划船',
            bodyPart: '背部',
            sets: [SetRecord(id: 'row-set', setType: TrainingSetType.working)],
          ),
        ],
      ),
      state: TrainingSessionState.resting,
      currentExerciseId: 'pull_up',
      currentSetId: 'pull-set',
      rest: RestState(
        setId: 'pull-set',
        restStartedAt: now,
        restDurationSeconds: 90,
      ),
      startedAt: now.subtract(const Duration(minutes: 20)),
      updatedAt: now,
    );
  }

  Future<({InMemoryTrainingRepository repository, Widget page})> setup() async {
    final current = active();
    final repository = InMemoryTrainingRepository(activeSession: current);
    final engine = TrainingSessionEngine(
      repository: repository,
      clock: () => now,
    );
    return (
      repository: repository,
      page: MaterialApp(
        home: ActiveTrainingPage(
          initialSession: current,
          engine: engine,
          repository: repository,
          catalog: exerciseCatalog,
          onSessionChanged: (_) {},
          onFinished: (_) async {},
          clock: () => now,
        ),
      ),
    );
  }

  testWidgets('recommendation changes session only after confirmation', (
    tester,
  ) async {
    final setupResult = await setup();
    await tester.pumpWidget(setupResult.page);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pump();
    expect(
      find.byKey(const Key('next-exercise-recommendation-card')),
      findsOneWidget,
    );
    expect(find.text('优先补充：坐姿划船'), findsOneWidget);
    expect(
      (await setupResult.repository.loadActiveSession())?.currentExerciseId,
      'pull_up',
    );

    await tester.tap(
      find.byKey(const Key('next-exercise-recommendation-apply')),
    );
    await tester.pumpAndSettle();
    expect(
      (await setupResult.repository.loadActiveSession())?.currentExerciseId,
      'pull_up',
    );
    await tester.tap(
      find.byKey(const Key('next-exercise-recommendation-confirm')),
    );
    await tester.pumpAndSettle();
    expect(
      (await setupResult.repository.loadActiveSession())?.currentExerciseId,
      'seated_cable_row',
    );
  });

  testWidgets('ignore keeps the active session unchanged', (tester) async {
    final setupResult = await setup();
    await tester.pumpWidget(setupResult.page);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('next-exercise-recommendation-ignore')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('next-exercise-recommendation-card')),
      findsNothing,
    );
    expect(
      (await setupResult.repository.loadActiveSession())?.currentExerciseId,
      'pull_up',
    );
  });
}
