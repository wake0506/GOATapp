import 'exercise_metadata.dart';

enum CoverageLevel { untrained, light, moderate, sufficient, high }

enum CoverageDataQuality { high, medium, low, insufficient }

class MuscleCoverageItem {
  const MuscleCoverageItem({
    required this.muscle,
    required this.level,
    required this.primaryContribution,
    required this.secondaryContribution,
    required this.effectiveSetCount,
    required this.contributingExerciseIds,
  });

  final MuscleGroup muscle;
  final CoverageLevel level;
  final int primaryContribution;
  final int secondaryContribution;
  final int effectiveSetCount;
  final List<String> contributingExerciseIds;

  int get contributionUnits => primaryContribution + secondaryContribution;
}

class RegionCoverageItem {
  const RegionCoverageItem({
    required this.region,
    required this.level,
    required this.contributionUnits,
    required this.contributingExerciseIds,
    this.contributingEffectiveSets = const {},
  });

  final MuscleRegion region;
  final CoverageLevel level;
  final int contributionUnits;
  final List<String> contributingExerciseIds;
  final Map<String, int> contributingEffectiveSets;
}

class MovementCoverageItem {
  const MovementCoverageItem({
    required this.pattern,
    required this.effectiveSetCount,
    required this.level,
    required this.contributingExerciseIds,
  });

  final ExerciseMovementPattern pattern;
  final int effectiveSetCount;
  final CoverageLevel level;
  final List<String> contributingExerciseIds;
}

class TrainingCoverageResult {
  const TrainingCoverageResult({
    required this.sessionIds,
    required this.targetBodyParts,
    required this.targetMuscleGroups,
    required this.muscleCoverage,
    required this.regionCoverage,
    required this.movementPatternCoverage,
    required this.completedEffectiveSets,
    required this.dataQuality,
    required this.legacyResolvedExercises,
    required this.unresolvedExerciseIds,
  });

  final List<String> sessionIds;
  final List<String> targetBodyParts;
  final List<MuscleGroup> targetMuscleGroups;
  final List<MuscleCoverageItem> muscleCoverage;
  final List<RegionCoverageItem> regionCoverage;
  final List<MovementCoverageItem> movementPatternCoverage;
  final int completedEffectiveSets;
  final CoverageDataQuality dataQuality;
  final int legacyResolvedExercises;
  final List<String> unresolvedExerciseIds;

  MuscleCoverageItem muscle(MuscleGroup group) => muscleCoverage.firstWhere(
    (item) => item.muscle == group,
    orElse: () => MuscleCoverageItem(
      muscle: group,
      level: CoverageLevel.untrained,
      primaryContribution: 0,
      secondaryContribution: 0,
      effectiveSetCount: 0,
      contributingExerciseIds: const [],
    ),
  );

  RegionCoverageItem region(MuscleRegion region) => regionCoverage.firstWhere(
    (item) => item.region == region,
    orElse: () => RegionCoverageItem(
      region: region,
      level: CoverageLevel.untrained,
      contributionUnits: 0,
      contributingExerciseIds: const [],
    ),
  );

  MovementCoverageItem movement(ExerciseMovementPattern pattern) =>
      movementPatternCoverage.firstWhere(
        (item) => item.pattern == pattern,
        orElse: () => MovementCoverageItem(
          pattern: pattern,
          effectiveSetCount: 0,
          level: CoverageLevel.untrained,
          contributingExerciseIds: const [],
        ),
      );
}

String coverageLevelLabel(CoverageLevel level) => switch (level) {
  CoverageLevel.untrained => '暂无记录',
  CoverageLevel.light => '较少',
  CoverageLevel.moderate => '适中',
  CoverageLevel.sufficient => '较多',
  CoverageLevel.high => '集中较多',
};

String coverageQualityLabel(CoverageDataQuality quality) => switch (quality) {
  CoverageDataQuality.high => '数据充分',
  CoverageDataQuality.medium => '部分动作按大肌群统计',
  CoverageDataQuality.low => '精细元数据有限',
  CoverageDataQuality.insufficient => '暂无训练记录',
};
