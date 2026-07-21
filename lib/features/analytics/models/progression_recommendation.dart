enum ProgressionRecommendationType {
  increaseWeight,
  increaseReps,
  keep,
  decreaseWeight,
  insufficientData,
}

enum ProgressionDataQuality { high, medium, low, insufficient }

enum ProgressionReason {
  allTargetRepsCompleted,
  highRirReserve,
  targetRepsIncomplete,
  reachedFailure,
  repeatedUnderperformance,
  missingRir,
  missingProgressionTarget,
  insufficientHistory,
  supersetContext,
  legacyNameMatch,
}

extension ProgressionReasonStorage on ProgressionReason {
  String get code => switch (this) {
    ProgressionReason.allTargetRepsCompleted => 'all_target_reps_completed',
    ProgressionReason.highRirReserve => 'high_rir_reserve',
    ProgressionReason.targetRepsIncomplete => 'target_reps_incomplete',
    ProgressionReason.reachedFailure => 'reached_failure',
    ProgressionReason.repeatedUnderperformance => 'repeated_underperformance',
    ProgressionReason.missingRir => 'missing_rir',
    ProgressionReason.missingProgressionTarget => 'missing_progression_target',
    ProgressionReason.insufficientHistory => 'insufficient_history',
    ProgressionReason.supersetContext => 'superset_context',
    ProgressionReason.legacyNameMatch => 'legacy_name_match',
  };
}

class ProgressionRecommendation {
  const ProgressionRecommendation({
    required this.exerciseId,
    required this.type,
    required this.dataQuality,
    required this.reasons,
    required this.requiresUserConfirmation,
    this.suggestedWeightKg,
    this.targetSets,
    this.targetRepMin,
    this.targetRepMax,
    this.basedOnSessionId,
    this.basedOnSessionDate,
  });

  final String exerciseId;
  final ProgressionRecommendationType type;
  final ProgressionDataQuality dataQuality;
  final List<ProgressionReason> reasons;
  final bool requiresUserConfirmation;
  final double? suggestedWeightKg;
  final int? targetSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final String? basedOnSessionId;
  final DateTime? basedOnSessionDate;
}
