import '../features/training/domain/active_training_session.dart';
import '../features/training/services/last_performance_resolver.dart';
import '../models/training.dart';
import 'training_repository.dart';

class InMemoryTrainingRepository implements TrainingRepository {
  InMemoryTrainingRepository({
    Iterable<TrainingSession> completedSessions = const [],
    ActiveTrainingSession? activeSession,
  }) : _sessions = [...completedSessions],
       _activeSession = activeSession;

  final List<TrainingSession> _sessions;
  ActiveTrainingSession? _activeSession;

  @override
  Future<List<TrainingSession>> listCompletedSessions() async =>
      List.unmodifiable(_sessions);

  @override
  Future<ActiveTrainingSession?> loadActiveSession() async => _activeSession;

  @override
  Future<void> saveActiveSession(ActiveTrainingSession session) async {
    _activeSession = session;
  }

  @override
  Future<void> clearActiveSession() async {
    _activeSession = null;
  }

  @override
  Future<void> saveSession(TrainingSession session) async {
    final index = _sessions.indexWhere(
      (candidate) => candidate.id == session.id,
    );
    if (index == -1) {
      _sessions.add(session);
    } else {
      _sessions[index] = session;
    }
  }

  @override
  Future<TrainingSession> finishActiveSession(String activeSessionId) async {
    final active = _activeSession;
    if (active == null || active.id != activeSessionId) {
      throw StateError('Active training session was not found.');
    }
    await saveSession(active.draft);
    await clearActiveSession();
    return active.draft;
  }

  @override
  Future<ExercisePerformance?> findLastPerformance(
    ExerciseReference exercise, {
    int? setOrdinal,
  }) async => LastPerformanceResolver().resolve(
    sessions: _sessions,
    exercise: exercise,
    setOrdinal: setOrdinal,
  );
}
