import '../../../exercise_catalog.dart';

class TrainingTemplate {
  const TrainingTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
  });

  final String id;
  final String name;
  final List<String> exerciseIds;

  List<ExerciseDefinition> resolveExercises(
    Iterable<ExerciseDefinition> catalog,
  ) {
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final seen = <String>{};
    return exerciseIds
        .where(seen.add)
        .map((id) => byId[id])
        .whereType<ExerciseDefinition>()
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exerciseIds': exerciseIds,
  };

  factory TrainingTemplate.fromJson(Map<String, dynamic> json) {
    return TrainingTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      exerciseIds: (json['exerciseIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }
}
