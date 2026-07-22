import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/exercise_metadata_catalog.dart';

void main() {
  test('all 143 catalog exercises have unique stable reviewed metadata', () {
    expect(exerciseCatalog, hasLength(143));
    final ids = exerciseCatalog.map((exercise) => exercise.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(exerciseMetadataCatalog.keys.toSet(), ids.toSet());
    expect(
      exerciseCatalog.map((exercise) => exercise.metadata),
      everyElement(isNotNull),
    );
  });

  test('metadata taxonomy and region mappings remain internally valid', () {
    for (final entry in exerciseMetadataCatalog.entries) {
      final metadata = entry.value;
      expect(metadata.exerciseId, entry.key);
      expect(
        metadata.primaryMuscles.toSet().intersection(
          metadata.secondaryMuscles.toSet(),
        ),
        isEmpty,
        reason: entry.key,
      );
      for (final region in metadata.muscleRegions) {
        expect(
          {...metadata.primaryMuscles, ...metadata.secondaryMuscles},
          contains(muscleGroupForRegion(region)),
          reason: '${entry.key}: ${region.name}',
        );
      }
      if (metadata.status == ExerciseMetadataStatus.unresolved) {
        expect(metadata.fallbackBodyPart.trim(), isNotEmpty, reason: entry.key);
      } else {
        expect(metadata.primaryMuscles, isNotEmpty, reason: entry.key);
        expect(metadata.muscleRegions, isNotEmpty, reason: entry.key);
        expect(
          metadata.movementPattern,
          isNot(ExerciseMovementPattern.other),
          reason: entry.key,
        );
      }
    }
  });

  test(
    'uncertain multi-pattern actions stay unresolved instead of guessed',
    () {
      const unresolvedIds = {
        'clean',
        'snatch',
        'clean_and_jerk',
        'turkish_get_up',
      };
      expect(
        exerciseMetadataCatalog.values
            .where(
              (metadata) =>
                  metadata.status == ExerciseMetadataStatus.unresolved,
            )
            .map((metadata) => metadata.exerciseId)
            .toSet(),
        unresolvedIds,
      );
      expect(
        exerciseMetadataCatalog.values.where(
          (metadata) => metadata.status == ExerciseMetadataStatus.reviewed,
        ),
        hasLength(139),
      );
    },
  );
}
