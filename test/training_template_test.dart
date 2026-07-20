import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/training_draft_factory.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/features/training/services/training_template_store.dart';
import 'package:goat_app/features/training/widgets/training_template_manager_sheet.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bench = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '哑铃平板卧推',
  );
  final row = exerciseCatalog.firstWhere((exercise) => exercise.name == '坐姿划船');
  final visibleBackExercise = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '传统硬拉',
  );
  final visibleChestExercise = exerciseCatalog.firstWhere(
    (exercise) => exercise.name == '杠铃平板卧推',
  );

  test('multi-exercise selection creates an ordered active-session draft', () {
    final draft = const TrainingDraftFactory().create(
      id: 'draft-1',
      name: '上肢训练',
      date: '2026-07-18',
      exercises: [bench, row],
    );

    expect(draft.exercises, hasLength(2));
    expect(draft.exercises.map((exercise) => exercise.orderIndex), [0, 1]);
    expect(
      draft.exercises.every((exercise) => exercise.sets.length == 4),
      isTrue,
    );
    expect(
      draft.exercises
          .expand((exercise) => exercise.sets)
          .every((set) => set.setType == TrainingSetType.working),
      isTrue,
    );
    expect(
      draft.exercises
          .expand((exercise) => exercise.sets)
          .map((set) => set.id)
          .toSet(),
      hasLength(8),
    );
  });

  test(
    'custom training templates can be created, edited and deleted locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'guest',
      );
      const original = TrainingTemplate(
        id: 'template-1',
        name: '背部日',
        exerciseIds: ['legacy-id'],
      );
      await store.save(original);
      expect(store.load().single.name, '背部日');

      final edited = TrainingTemplate(
        id: original.id,
        name: '背部力量日',
        exerciseIds: [row.id],
      );
      await store.save(edited);
      expect(store.load(), hasLength(1));
      expect(store.load().single.name, '背部力量日');
      expect(
        store.load().single.resolveExercises(exerciseCatalog).single.name,
        '坐姿划船',
      );

      await store.delete(original.id);
      expect(store.load(), isEmpty);
    },
  );

  testWidgets('template manager starts a saved custom plan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TrainingTemplateStore(
      preferences: preferences,
      namespace: 'guest',
    );
    final saved = TrainingTemplate(
      id: 'saved-plan',
      name: '我的背部方案',
      exerciseIds: [row.id],
    );
    await store.save(saved);
    TrainingTemplate? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await TrainingTemplateManagerSheet.show(
                  context,
                  catalog: exerciseCatalog,
                  store: store,
                );
              },
              child: const Text('管理方案'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('管理方案'));
    await tester.pumpAndSettle();
    expect(find.text('我的背部方案'), findsOneWidget);
    expect(find.textContaining('坐姿划船'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('training-template-start-saved-plan')),
    );
    await tester.pumpAndSettle();
    expect(result?.id, 'saved-plan');

    final repository = InMemoryTrainingRepository();
    await TrainingSessionEngine(repository: repository).startSession(
      activeSessionId: 'active-saved-plan',
      draft: const TrainingDraftFactory().create(
        id: 'session-saved-plan',
        name: result!.name,
        date: '2026-07-20',
        exercises: result!.resolveExercises(exerciseCatalog),
        setsPerExercise: 1,
      ),
    );
    expect(await repository.listCompletedSessions(), isEmpty);
    expect(
      (await repository.loadActiveSession())?.draft.exercises.single.exerciseId,
      row.id,
    );
  });

  testWidgets('template editor creates a reusable multi-part plan', (
    tester,
  ) async {
    TrainingTemplate? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await TrainingTemplateEditorSheet.show(
                  context,
                  catalog: exerciseCatalog,
                );
              },
              child: const Text('创建'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('training-template-name')),
      '上肢综合',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('template-exercise-${visibleChestExercise.id}')),
    );
    await tester.tap(find.byKey(const Key('template-body-part-背部')));
    await tester.pump();
    await tester.tap(
      find.byKey(Key('template-exercise-${visibleBackExercise.id}')),
    );
    await tester.pump();
    expect(find.textContaining('已选 2 个动作'), findsOneWidget);

    await tester.tap(find.byKey(const Key('training-template-save')));
    await tester.pumpAndSettle();
    expect(result?.name, '上肢综合');
    expect(result?.exerciseIds, [
      visibleChestExercise.id,
      visibleBackExercise.id,
    ]);
  });

  testWidgets('template editor preserves ID and can change exercise order', (
    tester,
  ) async {
    final existing = TrainingTemplate(
      id: 'stable-template',
      name: '原方案',
      exerciseIds: [visibleChestExercise.id, visibleBackExercise.id],
    );
    TrainingTemplate? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await TrainingTemplateEditorSheet.show(
                  context,
                  catalog: exerciseCatalog,
                  existing: existing,
                );
              },
              child: const Text('编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final chestFinder = find.byKey(
      Key('template-exercise-${visibleChestExercise.id}'),
    );
    await tester.tap(chestFinder);
    await tester.pump();
    await tester.tap(chestFinder);
    await tester.pump();
    await tester.tap(find.byKey(const Key('training-template-save')));
    await tester.pumpAndSettle();

    expect(result?.id, existing.id);
    expect(result?.exerciseIds, [
      visibleBackExercise.id,
      visibleChestExercise.id,
    ]);
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('template sheets fit ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrainingTemplateEditorSheet(catalog: exerciseCatalog),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('template-body-part-背部')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('training-template-save')), findsOneWidget);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'responsive-${size.width}',
      );
      await store.save(
        TrainingTemplate(
          id: 'responsive-plan',
          name: '响应式方案',
          exerciseIds: [visibleChestExercise.id],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingTemplateManagerSheet(
              catalog: exerciseCatalog,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('响应式方案'), findsOneWidget);
    });
  }
}
