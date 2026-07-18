import '../features/training/domain/active_training_session.dart';
import '../models/training.dart';

abstract interface class TrainingRepository {
  Future<List<TrainingSession>> listCompletedSessions();

  Future<ActiveTrainingSession?> loadActiveSession();

  Future<void> saveActiveSession(ActiveTrainingSession session);

  Future<void> clearActiveSession();

  Future<void> saveSession(TrainingSession session);

  Future<TrainingSession> finishActiveSession(String activeSessionId);

  Future<ExercisePerformance?> findLastPerformance(
    ExerciseReference exercise, {
    int? setOrdinal,
  });
}

class ExerciseReference {
  const ExerciseReference({this.exerciseId, required this.exerciseName});

  final String? exerciseId;
  final String exerciseName;
}

class ExercisePerformance {
  const ExercisePerformance({
    required this.sessionId,
    required this.sessionDate,
    required this.exercise,
    required this.set,
    required this.setOrdinal,
    required this.matchedByStableId,
  });

  final String sessionId;
  final String sessionDate;
  final TrainingExercise exercise;
  final SetRecord set;
  final int setOrdinal;
  final bool matchedByStableId;
}
