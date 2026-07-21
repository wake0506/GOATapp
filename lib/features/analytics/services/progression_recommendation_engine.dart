import '../../../models/progression_target.dart';
import '../../../models/training.dart';
import '../../training/domain/training_session_state.dart';
import '../models/progression_recommendation.dart';

class ProgressionRecommendationEngine {
  const ProgressionRecommendationEngine();

  ProgressionRecommendation recommend({
    required String exerciseId,
    required String exerciseName,
    required Iterable<TrainingSession> completedSessions,
    required ProgressionTarget? target,
  }) {
    final matches = <_ExercisePerformance>[];
    var usedLegacyNameMatch = false;
    final normalizedName = _normalizeName(exerciseName);

    for (final session in completedSessions) {
      final date = DateTime.tryParse(session.date);
      if (date == null) continue;
      for (final exercise in session.exercises) {
        final stableMatch = exercise.exerciseId == exerciseId;
        final legacyMatch =
            exercise.exerciseId == null &&
            _normalizeName(exercise.exerciseName) == normalizedName;
        if (!stableMatch && !legacyMatch) continue;
        usedLegacyNameMatch = usedLegacyNameMatch || legacyMatch;
        final sourceSets = exercise.sets
            .where(
              (set) =>
                  !set.replacementPlaceholder &&
                  set.reps > 0 &&
                  (set.resolvedSetType == TrainingSetType.working ||
                      set.resolvedSetType == TrainingSetType.superset),
            )
            .toList(growable: false);
        if (sourceSets.isEmpty) continue;
        matches.add(
          _ExercisePerformance(
            sessionId: session.id,
            date: date,
            sourceSets: sourceSets,
            hasFailureContext: exercise.sets.any(
              (set) =>
                  !set.replacementPlaceholder &&
                  (set.reachedFailure == true ||
                      set.resolvedSetType == TrainingSetType.failure),
            ),
          ),
        );
      }
    }

    matches.sort((a, b) => b.date.compareTo(a.date));
    if (matches.isEmpty) {
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        type: ProgressionRecommendationType.insufficientData,
        dataQuality: ProgressionDataQuality.insufficient,
        reasons: [ProgressionReason.insufficientHistory],
        requiresUserConfirmation: true,
      );
    }
    if (target == null) {
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        type: ProgressionRecommendationType.keep,
        dataQuality: ProgressionDataQuality.low,
        reasons: [
          ProgressionReason.missingProgressionTarget,
          if (usedLegacyNameMatch) ProgressionReason.legacyNameMatch,
        ],
        requiresUserConfirmation: true,
        basedOnSessionId: matches.first.sessionId,
        basedOnSessionDate: matches.first.date,
      );
    }

    final latest = matches.first;
    final relevant = latest.sourceSets.take(target.targetSets).toList();
    final reasons = <ProgressionReason>[];
    if (usedLegacyNameMatch) reasons.add(ProgressionReason.legacyNameMatch);
    if (latest.sourceSets.any(
      (set) => set.resolvedSetType == TrainingSetType.superset,
    )) {
      reasons.add(ProgressionReason.supersetContext);
    }
    if (latest.hasFailureContext) reasons.add(ProgressionReason.reachedFailure);
    final missingRir = relevant.any((set) => set.rir == null);
    if (missingRir) reasons.add(ProgressionReason.missingRir);

    final repeatedUnderperformance =
        matches.take(2).length == 2 &&
        matches
            .take(2)
            .every(
              (performance) => _isSevereUnderperformance(performance, target),
            );
    if (repeatedUnderperformance) {
      reasons.add(ProgressionReason.repeatedUnderperformance);
      return _result(
        exerciseId,
        latest,
        ProgressionRecommendationType.decreaseWeight,
        target,
        reasons,
        _quality(matches.length, usedLegacyNameMatch, missingRir, reasons),
      );
    }

    final enoughSets = relevant.length == target.targetSets;
    final allAtMax =
        enoughSets && relevant.every((set) => set.reps >= target.targetRepMax);
    final availableRirSupportsIncrease = relevant
        .where((set) => set.rir != null)
        .every((set) => set.rir! >= 2);
    if (allAtMax && availableRirSupportsIncrease && !latest.hasFailureContext) {
      reasons.add(ProgressionReason.allTargetRepsCompleted);
      if (!missingRir) reasons.add(ProgressionReason.highRirReserve);
      final weights = relevant.map((set) => set.weight).toSet();
      final suggestedWeight = target.weightStepKg != null && weights.length == 1
          ? weights.single + target.weightStepKg!
          : null;
      return _result(
        exerciseId,
        latest,
        ProgressionRecommendationType.increaseWeight,
        target,
        reasons,
        _quality(matches.length, usedLegacyNameMatch, missingRir, reasons),
        suggestedWeightKg: suggestedWeight,
      );
    }

    if (allAtMax) {
      return _result(
        exerciseId,
        latest,
        ProgressionRecommendationType.keep,
        target,
        reasons,
        _quality(matches.length, usedLegacyNameMatch, missingRir, reasons),
      );
    }

    reasons.add(ProgressionReason.targetRepsIncomplete);
    final allWithinRange =
        enoughSets && relevant.every((set) => set.reps >= target.targetRepMin);
    return _result(
      exerciseId,
      latest,
      allWithinRange
          ? ProgressionRecommendationType.increaseReps
          : ProgressionRecommendationType.keep,
      target,
      reasons,
      _quality(matches.length, usedLegacyNameMatch, missingRir, reasons),
    );
  }

  bool _isSevereUnderperformance(
    _ExercisePerformance performance,
    ProgressionTarget target,
  ) {
    final sets = performance.sourceSets.take(target.targetSets).toList();
    if (sets.isEmpty || !sets.any((set) => set.reps < target.targetRepMin)) {
      return false;
    }
    return performance.hasFailureContext ||
        sets.any((set) => set.reps < target.targetRepMin && set.rir == 0);
  }

  ProgressionDataQuality _quality(
    int historyCount,
    bool usedLegacyNameMatch,
    bool missingRir,
    List<ProgressionReason> reasons,
  ) {
    if (usedLegacyNameMatch || historyCount == 1) {
      return ProgressionDataQuality.low;
    }
    if (missingRir || reasons.contains(ProgressionReason.supersetContext)) {
      return ProgressionDataQuality.medium;
    }
    return ProgressionDataQuality.high;
  }

  ProgressionRecommendation _result(
    String exerciseId,
    _ExercisePerformance basedOn,
    ProgressionRecommendationType type,
    ProgressionTarget target,
    List<ProgressionReason> reasons,
    ProgressionDataQuality quality, {
    double? suggestedWeightKg,
  }) {
    return ProgressionRecommendation(
      exerciseId: exerciseId,
      type: type,
      dataQuality: quality,
      reasons: List.unmodifiable(reasons),
      requiresUserConfirmation: true,
      suggestedWeightKg: suggestedWeightKg,
      targetSets: target.targetSets,
      targetRepMin: target.targetRepMin,
      targetRepMax: target.targetRepMax,
      basedOnSessionId: basedOn.sessionId,
      basedOnSessionDate: basedOn.date,
    );
  }
}

class _ExercisePerformance {
  const _ExercisePerformance({
    required this.sessionId,
    required this.date,
    required this.sourceSets,
    required this.hasFailureContext,
  });

  final String sessionId;
  final DateTime date;
  final List<SetRecord> sourceSets;
  final bool hasFailureContext;
}

String _normalizeName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
