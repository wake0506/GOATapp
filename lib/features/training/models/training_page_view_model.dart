import '../../../models/training.dart';
import '../../analytics/models/analytics_date_range.dart';
import '../../analytics/models/effective_set_summary.dart';
import '../../analytics/services/effective_set_calculator.dart';

class TrainingStatusSummary {
  const TrainingStatusSummary({
    required this.volume,
    required this.durationMinutes,
    required this.completedSets,
  });

  final double volume;
  final int durationMinutes;
  final int completedSets;
}

class MuscleLoad {
  const MuscleLoad({
    required this.label,
    required this.englishLabel,
    required this.value,
    required this.effectiveSets,
  });

  final String label;
  final String englishLabel;
  final double value;
  final int effectiveSets;
}

class PersonalBest {
  const PersonalBest({
    required this.label,
    required this.englishLabel,
    this.weight,
    this.date,
  });

  final String label;
  final String englishLabel;
  final double? weight;
  final String? date;
}

class TrainingPageViewModel {
  const TrainingPageViewModel({
    required this.status,
    required this.muscleLoads,
    required this.personalBests,
    required this.legacyInferredSets,
  });

  final TrainingStatusSummary status;
  final List<MuscleLoad> muscleLoads;
  final List<PersonalBest> personalBests;
  final int legacyInferredSets;

  factory TrainingPageViewModel.fromSessions({
    required Iterable<TrainingSession> sessions,
    required String businessDate,
  }) {
    final allSessions = sessions.toList(growable: false);
    final today = allSessions
        .where((session) => session.date == businessDate)
        .toList(growable: false);
    final businessDay = DateTime.tryParse(businessDate) ?? DateTime(1970);
    final effectiveSummary = const EffectiveSetCalculator().calculate(
      completedSessions: allSessions,
      dateRange: AnalyticsDateRange(
        start: businessDay.subtract(const Duration(days: 6)),
        end: businessDay,
      ),
    );
    final activeGroups = effectiveSummary.groups
        .where((group) => group.effectiveSets > 0)
        .toList(growable: false);
    final peakLoad = activeGroups.fold<double>(
      0,
      (peak, group) =>
          group.effectiveSets > peak ? group.effectiveSets.toDouble() : peak,
    );

    return TrainingPageViewModel(
      status: TrainingStatusSummary(
        volume: today.fold<double>(
          0,
          (total, session) => total + session.sessionVolume,
        ),
        durationMinutes: _durationMinutes(today),
        completedSets: _setCount(today),
      ),
      muscleLoads: activeGroups
          .map(
            (group) => MuscleLoad(
              label: _groupLabel(group.muscleGroup),
              englishLabel: _groupEnglishLabel(group.muscleGroup),
              effectiveSets: group.effectiveSets,
              value: peakLoad == 0
                  ? 0
                  : (group.effectiveSets / peakLoad * 100)
                        .clamp(0, 100)
                        .toDouble(),
            ),
          )
          .toList(growable: false),
      personalBests: [
        _findPersonalBest(allSessions, '卧推', 'Bench Press'),
        _findPersonalBest(allSessions, '深蹲', 'Squat'),
        _findPersonalBest(allSessions, '硬拉', 'Deadlift'),
      ],
      legacyInferredSets: effectiveSummary.legacyInferredSets,
    );
  }

  static int _setCount(Iterable<TrainingSession> sessions) =>
      sessions.fold<int>(
        0,
        (total, session) =>
            total +
            session.exercises.fold<int>(
              0,
              (exerciseTotal, exercise) => exerciseTotal + exercise.sets.length,
            ),
      );

  static int _durationMinutes(Iterable<TrainingSession> sessions) {
    final seconds = sessions.fold<int>(
      0,
      (total, session) =>
          total +
          session.exercises.fold<int>(
            0,
            (exerciseTotal, exercise) =>
                exerciseTotal +
                exercise.sets.fold<int>(
                  0,
                  (setTotal, set) => setTotal + set.durationSec,
                ),
          ),
    );
    return (seconds / 60).round();
  }

  static String _groupLabel(AnalyticsMuscleGroup group) => switch (group) {
    AnalyticsMuscleGroup.chest => '胸部',
    AnalyticsMuscleGroup.back => '背部',
    AnalyticsMuscleGroup.legs => '腿部',
    AnalyticsMuscleGroup.shoulders => '肩部',
    AnalyticsMuscleGroup.arms => '手臂',
    AnalyticsMuscleGroup.core => '核心',
    AnalyticsMuscleGroup.glutes => '臀部',
    AnalyticsMuscleGroup.fullBody => '全身/体能',
  };

  static String _groupEnglishLabel(AnalyticsMuscleGroup group) =>
      switch (group) {
        AnalyticsMuscleGroup.chest => 'Chest',
        AnalyticsMuscleGroup.back => 'Back',
        AnalyticsMuscleGroup.legs => 'Legs',
        AnalyticsMuscleGroup.shoulders => 'Shoulders',
        AnalyticsMuscleGroup.arms => 'Arms',
        AnalyticsMuscleGroup.core => 'Core',
        AnalyticsMuscleGroup.glutes => 'Glutes',
        AnalyticsMuscleGroup.fullBody => 'Full Body',
      };

  static PersonalBest _findPersonalBest(
    Iterable<TrainingSession> sessions,
    String keyword,
    String englishLabel,
  ) {
    double? weight;
    String? date;
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (!exercise.exerciseName.contains(keyword)) continue;
        for (final set in exercise.sets) {
          if (weight == null || set.weight > weight) {
            weight = set.weight;
            date = session.date;
          }
        }
      }
    }
    return PersonalBest(
      label: keyword,
      englishLabel: englishLabel,
      weight: weight,
      date: date,
    );
  }
}
