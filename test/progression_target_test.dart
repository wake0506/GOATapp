import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/training_draft_factory.dart';
import 'package:goat_app/models/progression_target.dart';
import 'package:goat_app/models/training.dart';

void main() {
  const target = ProgressionTarget(
    targetSets: 3,
    targetRepMin: 8,
    targetRepMax: 10,
    weightStepKg: 2.5,
  );

  test('valid target round trips while invalid or legacy JSON stays null', () {
    final parsed = ProgressionTarget.tryFromJson(target.toJson());
    expect(parsed?.targetSets, 3);
    expect(parsed?.weightStepKg, 2.5);
    expect(
      ProgressionTarget.tryFromJson({
        'targetSets': 3,
        'targetRepMin': 12,
        'targetRepMax': 8,
      }),
      isNull,
    );
    expect(ProgressionTarget.tryFromJson({'targetSets': '3'}), isNull);
    expect(
      ProgressionTarget.tryFromJson({
        'targetSets': 3,
        'targetRepMin': 0,
        'targetRepMax': 10,
      }),
      isNull,
    );
    expect(
      ProgressionTarget.tryFromJson({
        'targetSets': 3,
        'targetRepMin': 8,
        'targetRepMax': 10,
        'weightStepKg': 0,
      }),
      isNull,
    );
    expect(
      TrainingExercise.fromJson({
        'exerciseName': 'Bench',
        'bodyPart': 'chest',
        'sets': <Object>[],
      }).progressionTarget,
      isNull,
    );
  });

  test(
    'template target is persisted and snapshotted into a training draft',
    () {
      final exercise = exerciseCatalog.first;
      final decoded = TrainingTemplate.fromJson(
        TrainingTemplate(
          id: 'plan',
          name: 'Plan',
          exerciseIds: [exercise.id],
          progressionTargets: {exercise.id: target},
        ).toJson(),
      );
      expect(decoded.targetFor(exercise.id)?.targetRepMax, 10);

      final draft = const TrainingDraftFactory().create(
        id: 'draft',
        name: 'Plan',
        date: '2026-07-21',
        exercises: [exercise],
        progressionTargets: decoded.progressionTargets,
      );
      expect(draft.exercises.single.progressionTarget?.targetSets, 3);
      expect(
        TrainingExercise.fromJson(
          draft.exercises.single.toJson(),
        ).progressionTarget?.weightStepKg,
        2.5,
      );

      final edited = TrainingTemplate(
        id: decoded.id,
        name: 'Edited',
        exerciseIds: decoded.exerciseIds,
        progressionTargets: const {},
      );
      expect(draft.exercises.single.progressionTarget?.targetRepMax, 10);
      expect(edited.targetFor(exercise.id), isNull);
    },
  );

  test(
    'invalid template targets are ignored without dropping the template',
    () {
      final template = TrainingTemplate.fromJson({
        'id': 'legacy',
        'name': 'Legacy',
        'exerciseIds': ['bench'],
        'progressionTargets': {
          'bench': {'targetSets': 0, 'targetRepMin': 8, 'targetRepMax': 10},
        },
      });
      expect(template.exerciseIds, ['bench']);
      expect(template.progressionTargets, isEmpty);
    },
  );
}
