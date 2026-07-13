import '../../models/training.dart';

class TrainingDashboardData {
  final String businessDate;
  final List<TrainingSession> todaySessions;
  final List<TrainingSession> recentSessions;
  final int weekCount;
  final int monthCount;
  final int recentExerciseCount;

  const TrainingDashboardData({
    required this.businessDate,
    required this.todaySessions,
    required this.recentSessions,
    required this.weekCount,
    required this.monthCount,
    required this.recentExerciseCount,
  });

  bool get hasSessions => recentSessions.isNotEmpty;

  TrainingSession? get latestSession =>
      recentSessions.isEmpty ? null : recentSessions.first;

  factory TrainingDashboardData.fromSessions({
    required Iterable<TrainingSession> sessions,
    required String businessDate,
  }) {
    final sorted = sessions.toList()
      ..sort((left, right) => right.date.compareTo(left.date));
    final date = DateTime.tryParse(businessDate) ?? DateTime.now();
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(date.year, date.month);
    final monthEnd = DateTime(date.year, date.month + 1);
    bool isWithin(TrainingSession session, DateTime start, DateTime end) {
      final sessionDate = DateTime.tryParse(session.date);
      return sessionDate != null &&
          !sessionDate.isBefore(start) &&
          sessionDate.isBefore(end);
    }

    final weekSessions = sorted
        .where((session) => isWithin(session, weekStart, weekEnd))
        .toList();
    return TrainingDashboardData(
      businessDate: businessDate,
      todaySessions: sorted
          .where((session) => session.date == businessDate)
          .toList(),
      recentSessions: sorted.take(5).toList(),
      weekCount: weekSessions.length,
      monthCount: sorted
          .where((session) => isWithin(session, monthStart, monthEnd))
          .length,
      recentExerciseCount: weekSessions.fold<int>(
        0,
        (total, session) => total + session.exercises.length,
      ),
    );
  }
}
