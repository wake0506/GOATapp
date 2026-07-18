import '../../../exercise_catalog.dart';

class ExerciseConstraints {
  const ExerciseConstraints({
    this.unavailableEquipment = const {},
    this.excludedExerciseIds = const {},
  });

  final Set<String> unavailableEquipment;
  final Set<String> excludedExerciseIds;
}

class ExerciseReplacementCandidate {
  const ExerciseReplacementCandidate({
    required this.exercise,
    required this.isLowConfidence,
  });

  final ExerciseDefinition exercise;
  final bool isLowConfidence;
}

class ExerciseReplacementService {
  const ExerciseReplacementService();

  List<ExerciseReplacementCandidate> rank({
    required ExerciseDefinition original,
    required Iterable<ExerciseDefinition> catalog,
    ExerciseConstraints constraints = const ExerciseConstraints(),
  }) {
    final filtered = catalog.where(
      (candidate) =>
          !_isOriginal(candidate, original) &&
          !constraints.excludedExerciseIds.contains(candidate.id) &&
          !constraints.unavailableEquipment.contains(candidate.equipment),
    );
    final structured = filtered
        .where(
          (candidate) =>
              _overlap(candidate.primaryMuscles, original.primaryMuscles) > 0,
        )
        .map(
          (candidate) => ExerciseReplacementCandidate(
            exercise: candidate,
            isLowConfidence: false,
          ),
        )
        .toList();
    if (structured.isNotEmpty) {
      structured.sort(
        (left, right) =>
            _compareStructured(original, left.exercise, right.exercise),
      );
      return structured;
    }

    final fallback =
        filtered
            .where((candidate) => candidate.bodyPart == original.bodyPart)
            .map(
              (candidate) => ExerciseReplacementCandidate(
                exercise: candidate,
                isLowConfidence: true,
              ),
            )
            .toList()
          ..sort(
            (left, right) =>
                _stableKey(left.exercise).compareTo(_stableKey(right.exercise)),
          );
    return fallback;
  }

  bool _isOriginal(ExerciseDefinition candidate, ExerciseDefinition original) =>
      candidate.id == original.id;

  int _compareStructured(
    ExerciseDefinition original,
    ExerciseDefinition left,
    ExerciseDefinition right,
  ) {
    final primary = _overlap(
      right.primaryMuscles,
      original.primaryMuscles,
    ).compareTo(_overlap(left.primaryMuscles, original.primaryMuscles));
    if (primary != 0) return primary;
    final pattern = (right.movementPattern == original.movementPattern ? 1 : 0)
        .compareTo(left.movementPattern == original.movementPattern ? 1 : 0);
    if (pattern != 0) return pattern;
    final equipment = (right.equipment == original.equipment ? 1 : 0).compareTo(
      left.equipment == original.equipment ? 1 : 0,
    );
    if (equipment != 0) return equipment;
    final secondary = _overlap(
      right.secondaryMuscles,
      original.secondaryMuscles,
    ).compareTo(_overlap(left.secondaryMuscles, original.secondaryMuscles));
    if (secondary != 0) return secondary;
    return _stableKey(left).compareTo(_stableKey(right));
  }

  int _overlap(Iterable<String> left, Iterable<String> right) =>
      left.toSet().intersection(right.toSet()).length;

  String _stableKey(ExerciseDefinition exercise) => exercise.id;
}
