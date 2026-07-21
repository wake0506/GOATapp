import '../../../models/training.dart';

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
  });

  final String label;
  final String englishLabel;
  final double value;
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
  });

  final TrainingStatusSummary status;
  final List<MuscleLoad> muscleLoads;
  final List<PersonalBest> personalBests;

  factory TrainingPageViewModel.fromSessions({
    required Iterable<TrainingSession> sessions,
    required String businessDate,
  }) {
    final allSessions = sessions.toList(growable: false);
    final today = allSessions
        .where((session) => session.date == businessDate)
        .toList(growable: false);
    final businessDay = DateTime.tryParse(businessDate) ?? DateTime.now();
    final sevenDayStart = businessDay.subtract(const Duration(days: 6));
    final recentSessions = allSessions.where((session) {
      final sessionDate = DateTime.tryParse(session.date);
      return sessionDate != null &&
          !sessionDate.isBefore(sevenDayStart) &&
          !sessionDate.isAfter(businessDay);
    });

    final setsByGroup = <String, double>{
      '胸部': 0,
      '背部': 0,
      '腿部': 0,
      '肩部': 0,
      '手臂': 0,
      '核心': 0,
      '臀部': 0,
      '全身/体能': 0,
    };
    for (final session in recentSessions) {
      for (final exercise in session.exercises) {
        final group = _canonicalMuscleGroup(exercise.bodyPart);
        if (group != null) {
          setsByGroup[group] = (setsByGroup[group] ?? 0) + exercise.sets.length;
        }
      }
    }
    final peakLoad = setsByGroup.values.fold<double>(
      0,
      (peak, value) => value > peak ? value : peak,
    );
    final labels = <String, String>{
      '胸部': 'Chest',
      '背部': 'Back',
      '腿部': 'Legs',
      '肩部': 'Shoulders',
      '手臂': 'Arms',
      '核心': 'Core',
      '臀部': 'Glutes',
      '全身/体能': 'Full Body',
    };

    return TrainingPageViewModel(
      status: TrainingStatusSummary(
        volume: today.fold<double>(
          0,
          (total, session) => total + session.sessionVolume,
        ),
        durationMinutes: _durationMinutes(today),
        completedSets: _setCount(today),
      ),
      muscleLoads: labels.entries
          .map(
            (entry) => MuscleLoad(
              label: entry.key,
              englishLabel: entry.value,
              value: peakLoad == 0
                  ? 0
                  : ((setsByGroup[entry.key] ?? 0) / peakLoad * 100)
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

  static String? _canonicalMuscleGroup(String value) {
    if (value.contains('胸')) return '胸部';
    if (value.contains('背')) return '背部';
    if (value.contains('腿')) return '腿部';
    if (value.contains('肩')) return '肩部';
    if (value.contains('手臂') || value.contains('二头') || value.contains('三头')) {
      return '手臂';
    }
    if (value.contains('核心') || value.contains('腹')) return '核心';
    if (value.contains('臀')) return '臀部';
    if (value.contains('全身') || value.contains('体能')) return '全身/体能';
    return null;
  }

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
