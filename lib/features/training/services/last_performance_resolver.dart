import '../../../models/training.dart';
import '../../../repositories/training_repository.dart';
import '../domain/training_session_state.dart';

class LastPerformanceResolver {
  const LastPerformanceResolver();

  ExercisePerformance? resolve({
    required Iterable<TrainingSession> sessions,
    required ExerciseReference exercise,
    int? setOrdinal,
  }) {
    final orderedSessions = sessions.toList()
      ..sort((left, right) => right.date.compareTo(left.date));
    final stableId = exercise.exerciseId?.trim();
    final matchesByStableId = stableId != null && stableId.isNotEmpty;

    final matches = <_ExerciseMatch>[];
    for (final session in orderedSessions) {
      for (final candidate in session.exercises) {
        if (!_matches(candidate, exercise, matchesByStableId, stableId)) {
          continue;
        }
        final workingSets = candidate.sets
            .asMap()
            .entries
            .where((entry) => _isEligibleWorkingSet(entry.value))
            .toList(growable: false);
        if (workingSets.isNotEmpty) {
          matches.add(_ExerciseMatch(session, candidate, workingSets));
        }
      }
    }
    if (setOrdinal != null && setOrdinal >= 0) {
      for (final match in matches) {
        if (setOrdinal < match.workingSets.length) {
          return _performance(
            session: match.session,
            exercise: match.exercise,
            setEntry: match.workingSets[setOrdinal],
            matchedByStableId: matchesByStableId,
          );
        }
      }
    }
    if (matches.isNotEmpty) {
      final match = matches.first;
      return _performance(
        session: match.session,
        exercise: match.exercise,
        setEntry: match.workingSets.last,
        matchedByStableId: matchesByStableId,
      );
    }
    return null;
  }

  bool _matches(
    TrainingExercise candidate,
    ExerciseReference exercise,
    bool matchesByStableId,
    String? stableId,
  ) => matchesByStableId
      ? candidate.exerciseId == stableId
      : _normalizedName(candidate.exerciseName) ==
            _normalizedName(exercise.exerciseName);

  ExercisePerformance _performance({
    required TrainingSession session,
    required TrainingExercise exercise,
    required MapEntry<int, SetRecord> setEntry,
    required bool matchedByStableId,
  }) => ExercisePerformance(
    sessionId: session.id,
    sessionDate: session.date,
    exercise: exercise,
    set: setEntry.value,
    setOrdinal: setEntry.key,
    matchedByStableId: matchedByStableId,
  );

  bool _isEligibleWorkingSet(SetRecord set) =>
      !set.isLegacyBreakthrough &&
      set.resolvedSetType == TrainingSetType.working;

  String _normalizedName(String value) => value.trim().toLowerCase();
}

class _ExerciseMatch {
  const _ExerciseMatch(this.session, this.exercise, this.workingSets);

  final TrainingSession session;
  final TrainingExercise exercise;
  final List<MapEntry<int, SetRecord>> workingSets;
}
