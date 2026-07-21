import '../../../models/training.dart';
import '../../training/domain/training_session_state.dart';
import '../models/analytics_date_range.dart';
import '../models/effective_set_summary.dart';

class EffectiveSetCalculator {
  const EffectiveSetCalculator();

  EffectiveSetSummary calculate({
    required Iterable<TrainingSession> completedSessions,
    required AnalyticsDateRange dateRange,
  }) {
    final counters = {
      for (final group in AnalyticsMuscleGroup.values) group: _SetCounter(),
    };
    var completedSets = 0;
    var effectiveSets = 0;
    var warmupSets = 0;
    var legacyInferredSets = 0;
    var hasMetadataGap = false;

    for (final session in completedSessions) {
      final sessionDate = DateTime.tryParse(session.date);
      if (sessionDate == null || !dateRange.contains(sessionDate)) continue;
      for (final exercise in session.exercises) {
        final group = canonicalMuscleGroup(exercise.bodyPart);
        for (final set in exercise.sets) {
          if (set.replacementPlaceholder || set.reps <= 0) continue;
          if (group == null || exercise.exerciseId?.trim().isEmpty != false) {
            hasMetadataGap = true;
          }
          final isLegacyInferred = set.completedAt == null;
          completedSets++;
          if (isLegacyInferred) legacyInferredSets++;
          final isWarmup = set.resolvedSetType == TrainingSetType.warmup;
          if (isWarmup) warmupSets++;
          final isEffective = !isWarmup;
          if (isEffective) effectiveSets++;
          if (group != null) {
            final counter = counters[group]!;
            counter.completedSets++;
            if (isWarmup) counter.warmupSets++;
            if (isEffective) counter.effectiveSets++;
          }
        }
      }
    }

    return EffectiveSetSummary(
      dateRange: dateRange,
      completedSets: completedSets,
      effectiveSets: effectiveSets,
      warmupSets: warmupSets,
      legacyInferredSets: legacyInferredSets,
      groups: [
        for (final group in AnalyticsMuscleGroup.values)
          MuscleSetSummary(
            muscleGroup: group,
            completedSets: counters[group]!.completedSets,
            effectiveSets: counters[group]!.effectiveSets,
            warmupSets: counters[group]!.warmupSets,
          ),
      ],
      dataQuality: _dataQuality(
        completedSets: completedSets,
        legacyInferredSets: legacyInferredSets,
        hasMetadataGap: hasMetadataGap,
      ),
    );
  }

  EffectiveSetDataQuality _dataQuality({
    required int completedSets,
    required int legacyInferredSets,
    required bool hasMetadataGap,
  }) {
    if (completedSets == 0) return EffectiveSetDataQuality.insufficient;
    if (legacyInferredSets * 2 >= completedSets) {
      return EffectiveSetDataQuality.legacyHeavy;
    }
    if (legacyInferredSets > 0 || hasMetadataGap) {
      return EffectiveSetDataQuality.partial;
    }
    return EffectiveSetDataQuality.complete;
  }
}

AnalyticsMuscleGroup? canonicalMuscleGroup(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_/]+'),
    '',
  );
  if (normalized.contains('胸') || normalized == 'chest') {
    return AnalyticsMuscleGroup.chest;
  }
  if (normalized.contains('背') || normalized == 'back') {
    return AnalyticsMuscleGroup.back;
  }
  if (normalized.contains('腿') || normalized.contains('leg')) {
    return AnalyticsMuscleGroup.legs;
  }
  if (normalized.contains('肩') || normalized.contains('shoulder')) {
    return AnalyticsMuscleGroup.shoulders;
  }
  if (normalized.contains('手臂') ||
      normalized.contains('二头') ||
      normalized.contains('三头') ||
      normalized == 'arms' ||
      normalized == 'biceps' ||
      normalized == 'triceps') {
    return AnalyticsMuscleGroup.arms;
  }
  if (normalized.contains('核心') ||
      normalized.contains('腹') ||
      normalized == 'core') {
    return AnalyticsMuscleGroup.core;
  }
  if (normalized.contains('臀') || normalized.contains('glute')) {
    return AnalyticsMuscleGroup.glutes;
  }
  if (normalized.contains('全身') ||
      normalized.contains('体能') ||
      normalized == 'fullbody' ||
      normalized == 'conditioning') {
    return AnalyticsMuscleGroup.fullBody;
  }
  return null;
}

class _SetCounter {
  int completedSets = 0;
  int effectiveSets = 0;
  int warmupSets = 0;
}
