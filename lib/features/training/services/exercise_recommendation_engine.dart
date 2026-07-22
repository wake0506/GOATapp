import '../../../exercise_catalog.dart';
import '../../../models/training.dart';
import '../models/exercise_metadata.dart';
import '../models/exercise_metadata_catalog.dart';
import '../models/exercise_recommendation.dart';
import '../models/training_coverage.dart';
import 'exercise_replacement_service.dart';

class ExerciseRecommendationEngine {
  const ExerciseRecommendationEngine({
    this.replacementService = const ExerciseReplacementService(),
  });

  final ExerciseReplacementService replacementService;

  List<ExerciseRecommendationResult> replacement({
    required ExerciseDefinition original,
    required Iterable<ExerciseDefinition> catalog,
    ExerciseConstraints constraints = const ExerciseConstraints(),
  }) {
    final candidates = replacementService.rank(
      original: original,
      catalog: catalog,
      constraints: constraints,
    );
    return [
      for (var index = 0; index < candidates.length; index++)
        ExerciseRecommendationResult(
          exercise: candidates[index].exercise,
          mode: ExerciseRecommendationMode.replacement,
          reasonCodes: [
            ExerciseRecommendationReason.sameTargetMuscle,
            if (candidates[index].isLowConfidence)
              ExerciseRecommendationReason.lowMetadataConfidence,
          ],
          dataQuality: candidates[index].isLowConfidence
              ? ExerciseRecommendationDataQuality.low
              : ExerciseRecommendationDataQuality.high,
          targetMuscles:
              exerciseMetadataById(
                candidates[index].exercise.id,
              )?.primaryMuscles ??
              const [],
          targetRegions:
              exerciseMetadataById(
                candidates[index].exercise.id,
              )?.muscleRegions ??
              const [],
          movementPattern: candidates[index].exercise.movementPattern,
          rank: index + 1,
        ),
    ];
  }

  List<ExerciseRecommendationResult> complementary({
    required TrainingSession currentSession,
    required TrainingCoverageResult coverageResult,
    required Iterable<ExerciseDefinition> catalog,
    ExerciseConstraints constraints = const ExerciseConstraints(),
    Set<String>? availableEquipment,
    Map<String, ExerciseMetadata>? metadataCatalog,
  }) {
    final metadata = metadataCatalog ?? exerciseMetadataCatalog;
    final performedIds = currentSession.exercises
        .where(
          (exercise) => exercise.sets.any((set) => set.completedAt != null),
        )
        .map((exercise) => exercise.exerciseId)
        .whereType<String>()
        .toSet();
    final plannedIds = currentSession.exercises
        .where(
          (exercise) =>
              exercise.exerciseId != null &&
              exercise.sets.any((set) => set.completedAt == null),
        )
        .map((exercise) => exercise.exerciseId!)
        .toSet();
    final targetGroups = coverageResult.targetMuscleGroups.toSet();
    final missingPatterns = _missingPatterns(coverageResult);
    final leastCoveredRegions = coverageResult.regionCoverage
        .where(
          (item) =>
              targetGroups.contains(muscleGroupForRegion(item.region)) &&
              (item.level == CoverageLevel.untrained ||
                  item.level == CoverageLevel.light),
        )
        .map((item) => item.region)
        .toSet();
    final maxPatternSets = coverageResult.movementPatternCoverage.fold<int>(
      0,
      (value, item) =>
          item.effectiveSetCount > value ? item.effectiveSetCount : value,
    );
    final ranked = <_RankedCandidate>[];

    for (final candidate in catalog) {
      if (performedIds.contains(candidate.id) ||
          constraints.excludedExerciseIds.contains(candidate.id) ||
          constraints.unavailableEquipment.contains(candidate.equipment) ||
          (availableEquipment != null &&
              !availableEquipment.contains(candidate.equipment))) {
        continue;
      }
      final candidateMetadata = metadata[candidate.id];
      if (candidateMetadata == null ||
          (candidateMetadata.status == ExerciseMetadataStatus.unresolved &&
              candidateMetadata.primaryMuscles.isEmpty)) {
        continue;
      }
      final targetMatch = candidateMetadata.primaryMuscles.any(
        targetGroups.contains,
      );
      if (targetGroups.isNotEmpty && !targetMatch) continue;
      final missingPattern = missingPatterns.contains(
        candidateMetadata.movementPattern,
      );
      final undercoveredRegion = candidateMetadata.muscleRegions.any(
        leastCoveredRegions.contains,
      );
      final currentPatternSets = coverageResult
          .movement(candidateMetadata.movementPattern)
          .effectiveSetCount;
      final avoidsRedundancy =
          maxPatternSets > 0 && currentPatternSets < maxPatternSets;
      ranked.add(
        _RankedCandidate(
          exercise: candidate,
          metadata: candidateMetadata,
          targetMatch: targetMatch,
          alreadyPlanned: plannedIds.contains(candidate.id),
          missingPattern: missingPattern,
          undercoveredRegion: undercoveredRegion,
          avoidsRedundancy: avoidsRedundancy,
          currentPatternSets: currentPatternSets,
        ),
      );
    }

    ranked.sort(_compareCandidates);
    return [
      for (var index = 0; index < ranked.length; index++)
        ExerciseRecommendationResult(
          exercise: ranked[index].exercise,
          mode: ExerciseRecommendationMode.complementary,
          reasonCodes: [
            if (ranked[index].undercoveredRegion)
              ExerciseRecommendationReason.undercoveredPrimaryRegion,
            if (ranked[index].missingPattern)
              ExerciseRecommendationReason.missingMovementPattern,
            if (ranked[index].avoidsRedundancy)
              ExerciseRecommendationReason.avoidPatternRedundancy,
            if (ranked[index].targetMatch)
              ExerciseRecommendationReason.sameTargetMuscle,
            ExerciseRecommendationReason.equipmentAvailable,
            if (ranked[index].metadata.status ==
                ExerciseMetadataStatus.unresolved)
              ExerciseRecommendationReason.lowMetadataConfidence,
          ],
          dataQuality:
              ranked[index].metadata.status == ExerciseMetadataStatus.unresolved
              ? ExerciseRecommendationDataQuality.low
              : coverageResult.dataQuality == CoverageDataQuality.high
              ? ExerciseRecommendationDataQuality.high
              : ExerciseRecommendationDataQuality.medium,
          targetMuscles: ranked[index].metadata.primaryMuscles,
          targetRegions: ranked[index].metadata.muscleRegions,
          movementPattern: ranked[index].metadata.movementPattern,
          rank: index + 1,
        ),
    ];
  }

  Set<ExerciseMovementPattern> _missingPatterns(
    TrainingCoverageResult coverage,
  ) {
    final expected = <ExerciseMovementPattern>{};
    for (final group in coverage.targetMuscleGroups) {
      expected.addAll(switch (group) {
        MuscleGroup.back => const {
          ExerciseMovementPattern.verticalPull,
          ExerciseMovementPattern.horizontalPull,
        },
        MuscleGroup.shoulders => const {
          ExerciseMovementPattern.verticalPush,
          ExerciseMovementPattern.shoulderIsolation,
        },
        MuscleGroup.arms => const {
          ExerciseMovementPattern.elbowFlexion,
          ExerciseMovementPattern.elbowExtension,
        },
        MuscleGroup.legs => const {
          ExerciseMovementPattern.squat,
          ExerciseMovementPattern.hinge,
          ExerciseMovementPattern.lunge,
        },
        MuscleGroup.glutes => const {
          ExerciseMovementPattern.hinge,
          ExerciseMovementPattern.hipAbduction,
        },
        MuscleGroup.core => const {ExerciseMovementPattern.core},
        MuscleGroup.chest => const {ExerciseMovementPattern.horizontalPush},
      });
    }
    return expected
        .where((pattern) => coverage.movement(pattern).effectiveSetCount == 0)
        .toSet();
  }

  int _compareCandidates(_RankedCandidate left, _RankedCandidate right) {
    var comparison = _boolCompare(right.missingPattern, left.missingPattern);
    if (comparison != 0) return comparison;
    comparison = _boolCompare(
      right.undercoveredRegion,
      left.undercoveredRegion,
    );
    if (comparison != 0) return comparison;
    comparison = _boolCompare(right.alreadyPlanned, left.alreadyPlanned);
    if (comparison != 0) return comparison;
    comparison = _boolCompare(right.targetMatch, left.targetMatch);
    if (comparison != 0) return comparison;
    comparison = _boolCompare(right.avoidsRedundancy, left.avoidsRedundancy);
    if (comparison != 0) return comparison;
    comparison = left.currentPatternSets.compareTo(right.currentPatternSets);
    if (comparison != 0) return comparison;
    return left.exercise.id.compareTo(right.exercise.id);
  }

  int _boolCompare(bool left, bool right) =>
      (left ? 1 : 0).compareTo(right ? 1 : 0);
}

class _RankedCandidate {
  const _RankedCandidate({
    required this.exercise,
    required this.metadata,
    required this.targetMatch,
    required this.alreadyPlanned,
    required this.missingPattern,
    required this.undercoveredRegion,
    required this.avoidsRedundancy,
    required this.currentPatternSets,
  });

  final ExerciseDefinition exercise;
  final ExerciseMetadata metadata;
  final bool targetMatch;
  final bool alreadyPlanned;
  final bool missingPattern;
  final bool undercoveredRegion;
  final bool avoidsRedundancy;
  final int currentPatternSets;
}
