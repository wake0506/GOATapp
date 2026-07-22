import 'analytics_date_range.dart';
import 'effective_set_summary.dart';
import 'weight_trend.dart';

enum WeeklyReviewDataQuality { complete, partial, insufficient }

enum WeeklyReviewReason {
  completeWeek,
  partialTrainingHistory,
  partialNutritionLogging,
  legacyTrainingData,
  weightTrendAvailable,
  insufficientWeightHistory,
}

class WeeklyTrainingReview {
  const WeeklyTrainingReview({
    required this.dateRange,
    required this.trainingDays,
    required this.sessionCount,
    required this.completedSets,
    required this.effectiveSets,
    required this.muscleGroups,
    required this.totalVolume,
    required this.dataQuality,
    required this.reasons,
    this.topTrainedGroup,
    this.previousSessionCount,
    this.previousEffectiveSets,
  });

  final AnalyticsDateRange dateRange;
  final int trainingDays;
  final int sessionCount;
  final int completedSets;
  final int effectiveSets;
  final List<MuscleSetSummary> muscleGroups;
  final double totalVolume;
  final AnalyticsMuscleGroup? topTrainedGroup;
  final int? previousSessionCount;
  final int? previousEffectiveSets;
  final WeeklyReviewDataQuality dataQuality;
  final List<WeeklyReviewReason> reasons;
}

class WeeklyNutritionReview {
  const WeeklyNutritionReview({
    required this.dateRange,
    required this.recordedDays,
    required this.dataQuality,
    required this.reasons,
    required this.weightTrend,
    this.averageCalories,
    this.averageProtein,
    this.averageCarbs,
    this.averageFat,
    this.previousAverageCalories,
  });

  final AnalyticsDateRange dateRange;
  final int recordedDays;
  final double? averageCalories;
  final double? averageProtein;
  final double? averageCarbs;
  final double? averageFat;
  final double? previousAverageCalories;
  final WeightTrend weightTrend;
  final WeeklyReviewDataQuality dataQuality;
  final List<WeeklyReviewReason> reasons;
}
