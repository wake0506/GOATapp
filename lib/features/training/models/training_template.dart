import '../../../exercise_catalog.dart';
import '../../../models/progression_target.dart';
import '../../../models/rest_prescription.dart';

class TrainingTemplate {
  const TrainingTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
    this.progressionTargets = const {},
    this.restPrescriptions = const {},
  });

  final String id;
  final String name;
  final List<String> exerciseIds;
  final Map<String, ProgressionTarget> progressionTargets;
  final Map<String, RestPrescription> restPrescriptions;

  ProgressionTarget? targetFor(String exerciseId) =>
      progressionTargets[exerciseId];

  RestPrescription restFor(String exerciseId) =>
      restPrescriptions[exerciseId] ?? const RestPrescription.recommended();

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
    'progressionTargets': progressionTargets.map(
      (exerciseId, target) => MapEntry(exerciseId, target.toJson()),
    ),
    'restPrescriptions': restPrescriptions.map(
      (exerciseId, prescription) => MapEntry(exerciseId, prescription.toJson()),
    ),
  };

  factory TrainingTemplate.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['progressionTargets'];
    final targets = <String, ProgressionTarget>{};
    if (rawTargets is Map) {
      for (final entry in rawTargets.entries) {
        final exerciseId = entry.key.toString();
        final target = ProgressionTarget.tryFromJson(entry.value);
        if (exerciseId.isNotEmpty && target != null) {
          targets[exerciseId] = target;
        }
      }
    }
    final rawRest = json['restPrescriptions'];
    final restPrescriptions = <String, RestPrescription>{};
    if (rawRest is Map) {
      for (final entry in rawRest.entries) {
        final exerciseId = entry.key.toString();
        final prescription = RestPrescription.tryFromJson(entry.value);
        if (exerciseId.isNotEmpty && prescription != null) {
          restPrescriptions[exerciseId] = prescription;
        }
      }
    }
    return TrainingTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      exerciseIds: (json['exerciseIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      progressionTargets: Map.unmodifiable(targets),
      restPrescriptions: Map.unmodifiable(restPrescriptions),
    );
  }
}
