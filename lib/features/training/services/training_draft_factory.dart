import '../../../exercise_catalog.dart';
import '../../../models/training.dart';
import '../../../models/progression_target.dart';
import '../domain/training_session_state.dart';

class TrainingDraftFactory {
  const TrainingDraftFactory();

  TrainingSession create({
    required String id,
    required String name,
    required String date,
    required List<ExerciseDefinition> exercises,
    int setsPerExercise = 4,
    Map<String, ProgressionTarget> progressionTargets = const {},
  }) {
    final seenExerciseIds = <String>{};
    final uniqueExercises = exercises
        .where((exercise) => seenExerciseIds.add(exercise.id))
        .toList(growable: false);
    return TrainingSession(
      id: id,
      name: name,
      date: date,
      exercises: [
        for (
          var exerciseIndex = 0;
          exerciseIndex < uniqueExercises.length;
          exerciseIndex++
        )
          TrainingExercise(
            exerciseId: uniqueExercises[exerciseIndex].id,
            exerciseName: uniqueExercises[exerciseIndex].name,
            bodyPart: uniqueExercises[exerciseIndex].bodyPart,
            orderIndex: exerciseIndex,
            progressionTarget:
                progressionTargets[uniqueExercises[exerciseIndex].id],
            sets: [
              for (var setIndex = 0; setIndex < setsPerExercise; setIndex++)
                SetRecord(
                  id: '$id-${uniqueExercises[exerciseIndex].id}-${setIndex + 1}',
                  setType: TrainingSetType.working,
                ),
            ],
          ),
      ],
    );
  }
}
