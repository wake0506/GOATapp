import '../../../exercise_catalog.dart';
import 'exercise_metadata.dart';

enum ExerciseRecommendationMode { replacement, complementary }

enum ExerciseRecommendationReason {
  undercoveredPrimaryRegion,
  missingMovementPattern,
  avoidPatternRedundancy,
  sameTargetMuscle,
  equipmentAvailable,
  lowMetadataConfidence,
}

enum ExerciseRecommendationDataQuality { high, medium, low }

class ExerciseRecommendationResult {
  const ExerciseRecommendationResult({
    required this.exercise,
    required this.mode,
    required this.reasonCodes,
    required this.dataQuality,
    required this.targetMuscles,
    required this.targetRegions,
    required this.movementPattern,
    required this.rank,
  });

  final ExerciseDefinition exercise;
  final ExerciseRecommendationMode mode;
  final List<ExerciseRecommendationReason> reasonCodes;
  final ExerciseRecommendationDataQuality dataQuality;
  final List<MuscleGroup> targetMuscles;
  final List<MuscleRegion> targetRegions;
  final ExerciseMovementPattern movementPattern;
  final int rank;
}

String exerciseRecommendationReasonLabel(ExerciseRecommendationReason reason) =>
    switch (reason) {
      ExerciseRecommendationReason.undercoveredPrimaryRegion => '补充当前覆盖较少的目标区域',
      ExerciseRecommendationReason.missingMovementPattern => '补充当前较少的动作模式',
      ExerciseRecommendationReason.avoidPatternRedundancy => '减少重复动作模式',
      ExerciseRecommendationReason.sameTargetMuscle => '符合本次训练目标',
      ExerciseRecommendationReason.equipmentAvailable => '当前器械可用',
      ExerciseRecommendationReason.lowMetadataConfidence => '仅按大肌群提供参考',
    };
