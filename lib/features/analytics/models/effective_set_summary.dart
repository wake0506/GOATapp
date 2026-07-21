import 'analytics_date_range.dart';

enum AnalyticsMuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  glutes,
  fullBody,
}

enum EffectiveSetDataQuality { complete, partial, legacyHeavy, insufficient }

class MuscleSetSummary {
  const MuscleSetSummary({
    required this.muscleGroup,
    required this.completedSets,
    required this.effectiveSets,
    required this.warmupSets,
  });

  final AnalyticsMuscleGroup muscleGroup;
  final int completedSets;
  final int effectiveSets;
  final int warmupSets;
}

class EffectiveSetSummary {
  const EffectiveSetSummary({
    required this.dateRange,
    required this.completedSets,
    required this.effectiveSets,
    required this.warmupSets,
    required this.legacyInferredSets,
    required this.groups,
    required this.dataQuality,
  });

  final AnalyticsDateRange dateRange;
  final int completedSets;
  final int effectiveSets;
  final int warmupSets;
  final int legacyInferredSets;
  final List<MuscleSetSummary> groups;
  final EffectiveSetDataQuality dataQuality;
}
