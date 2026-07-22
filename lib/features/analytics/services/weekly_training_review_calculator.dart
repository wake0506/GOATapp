import '../../../models/training.dart';
import '../models/analytics_date_range.dart';
import '../models/effective_set_summary.dart';
import '../models/weekly_review.dart';
import 'effective_set_calculator.dart';

class WeeklyTrainingReviewCalculator {
  const WeeklyTrainingReviewCalculator({
    this.effectiveSetCalculator = const EffectiveSetCalculator(),
  });

  final EffectiveSetCalculator effectiveSetCalculator;

  WeeklyTrainingReview calculate({
    required Iterable<TrainingSession> completedSessions,
    required DateTime anchorDate,
  }) {
    final anchor = dateOnly(anchorDate);
    final currentRange = AnalyticsDateRange(
      start: anchor.subtract(const Duration(days: 6)),
      end: anchor,
    );
    final previousRange = AnalyticsDateRange(
      start: anchor.subtract(const Duration(days: 13)),
      end: anchor.subtract(const Duration(days: 7)),
    );
    final sessions = completedSessions.toList(growable: false);
    final currentSessions = _sessionsInRange(sessions, currentRange);
    final previousSessions = _sessionsInRange(sessions, previousRange);
    final currentSets = effectiveSetCalculator.calculate(
      completedSessions: sessions,
      dateRange: currentRange,
    );
    final previousSets = effectiveSetCalculator.calculate(
      completedSessions: sessions,
      dateRange: previousRange,
    );
    final activeGroups = currentSets.groups
        .where((group) => group.effectiveSets > 0)
        .toList(growable: false);
    AnalyticsMuscleGroup? topGroup;
    var topCount = 0;
    for (final group in activeGroups) {
      if (group.effectiveSets > topCount) {
        topCount = group.effectiveSets;
        topGroup = group.muscleGroup;
      }
    }
    final reasons = <WeeklyReviewReason>[];
    if (currentSets.legacyInferredSets > 0) {
      reasons.add(WeeklyReviewReason.legacyTrainingData);
    }
    if (currentSessions.isEmpty) {
      reasons.add(WeeklyReviewReason.partialTrainingHistory);
    } else if (currentSets.dataQuality != EffectiveSetDataQuality.complete) {
      reasons.add(WeeklyReviewReason.partialTrainingHistory);
    }

    return WeeklyTrainingReview(
      dateRange: currentRange,
      trainingDays: currentSessions
          .map((session) => session.date)
          .toSet()
          .length,
      sessionCount: currentSessions.length,
      completedSets: currentSets.completedSets,
      effectiveSets: currentSets.effectiveSets,
      muscleGroups: List.unmodifiable(activeGroups),
      totalVolume: currentSessions.fold<double>(
        0,
        (sum, session) => sum + session.sessionVolume,
      ),
      topTrainedGroup: topGroup,
      previousSessionCount: previousSessions.isEmpty
          ? null
          : previousSessions.length,
      previousEffectiveSets: previousSessions.isEmpty
          ? null
          : previousSets.effectiveSets,
      dataQuality: currentSessions.isEmpty
          ? WeeklyReviewDataQuality.insufficient
          : currentSets.dataQuality == EffectiveSetDataQuality.complete
          ? WeeklyReviewDataQuality.complete
          : WeeklyReviewDataQuality.partial,
      reasons: List.unmodifiable(reasons),
    );
  }

  List<TrainingSession> _sessionsInRange(
    Iterable<TrainingSession> sessions,
    AnalyticsDateRange range,
  ) => sessions
      .where((session) {
        final date = DateTime.tryParse(session.date);
        return date != null && range.contains(date);
      })
      .toList(growable: false);
}
