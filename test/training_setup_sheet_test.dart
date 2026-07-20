import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/services/training_draft_factory.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/widgets/training_setup_sheet.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  Widget harness(ValueChanged<TrainingSetupSelection?> onResult) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              onResult(
                await TrainingSetupSheet.show(
                  context,
                  catalog: exerciseCatalog,
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
  }

  testWidgets('selects a body part and multiple exercises', (tester) async {
    TrainingSetupSelection? result;
    await tester.pumpWidget(harness((value) => result = value));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final startFinder = find.byKey(const Key('training-setup-start'));
    expect(tester.widget<FilledButton>(startFinder).onPressed, isNull);
    expect(find.text('传统硬拉'), findsNothing);

    await tester.tap(find.byKey(const Key('training-body-part-背部')));
    await tester.pumpAndSettle();
    expect(find.text('传统硬拉'), findsOneWidget);
    expect(find.text('杠铃平板卧推'), findsNothing);

    await tester.tap(find.text('杠铃俯身划船'));
    await tester.tap(find.text('传统硬拉'));
    await tester.tap(find.text('相扑硬拉'));
    await tester.pump();
    expect(tester.widget<FilledButton>(startFinder).onPressed, isNotNull);
    expect(find.text('已选 3 个'), findsOneWidget);

    await tester.tap(startFinder);
    await tester.pumpAndSettle();
    expect(result?.bodyPart, '背部');
    expect(result?.sessionName, '背部训练');
    expect(result?.exercises.map((exercise) => exercise.name), [
      '杠铃俯身划船',
      '传统硬拉',
      '相扑硬拉',
    ]);
    expect(
      result?.exercises.map((exercise) => exercise.id).toSet(),
      hasLength(3),
    );

    final repository = InMemoryTrainingRepository();
    await TrainingSessionEngine(repository: repository).startSession(
      activeSessionId: 'active-from-selector',
      draft: const TrainingDraftFactory().create(
        id: 'selector-session',
        name: result!.sessionName,
        date: '2026-07-20',
        exercises: result!.exercises,
        setsPerExercise: 1,
      ),
    );
    expect(await repository.listCompletedSessions(), isEmpty);
    final active = await repository.loadActiveSession();
    expect(active?.draft.exercises, hasLength(3));
    expect(active?.draft.exercises.map((exercise) => exercise.exerciseId), [
      ...result!.exercises.map((exercise) => exercise.id),
    ]);
  });

  testWidgets('filters the real catalog for chest, back and legs', (
    tester,
  ) async {
    await tester.pumpWidget(harness((_) {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('training-body-part-胸部')));
    await tester.pump();
    expect(find.text('杠铃平板卧推'), findsOneWidget);
    expect(find.text('传统硬拉'), findsNothing);

    await tester.tap(find.byKey(const Key('training-body-part-背部')));
    await tester.pump();
    expect(find.text('传统硬拉'), findsOneWidget);
    expect(find.text('杠铃平板卧推'), findsNothing);

    await tester.tap(find.byKey(const Key('training-body-part-腿部')));
    await tester.pump();
    expect(find.text('杠铃深蹲'), findsOneWidget);
    expect(find.text('传统硬拉'), findsNothing);
  });

  testWidgets('switching body part clears the current exercise selection', (
    tester,
  ) async {
    await tester.pumpWidget(harness((_) {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('training-body-part-胸部')));
    await tester.pump();
    await tester.tap(find.text('哑铃平板卧推'));
    await tester.pump();
    expect(find.text('已选 1 个'), findsOneWidget);

    await tester.tap(find.byKey(const Key('training-body-part-腿部')));
    await tester.pump();
    expect(find.text('已选 1 个'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('training-setup-start')))
          .onPressed,
      isNull,
    );
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('training setup fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrainingSetupSheet(catalog: exerciseCatalog)),
        ),
      );
      await tester.tap(find.byKey(const Key('training-body-part-背部')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('training-setup-start')), findsOneWidget);
    });
  }
}
