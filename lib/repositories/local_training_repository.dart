import '../features/training/domain/active_training_session.dart';
import '../features/training/services/last_performance_resolver.dart';
import '../models/app_snapshot.dart';
import '../models/training.dart';
import '../services/local_storage_service.dart';
import 'training_repository.dart';

class LocalTrainingRepository implements TrainingRepository {
  LocalTrainingRepository({
    required LocalStorageService storage,
    required String namespace,
    DateTime Function()? clock,
  }) : _storage = storage,
       _namespace = namespace,
       _clock = clock ?? DateTime.now;

  final LocalStorageService _storage;
  final String _namespace;
  final DateTime Function() _clock;

  AppSnapshot _snapshot() => _storage.load(_namespace) ?? AppSnapshot.empty();

  @override
  Future<List<TrainingSession>> listCompletedSessions() async =>
      List.unmodifiable(_snapshot().training);

  @override
  Future<ActiveTrainingSession?> loadActiveSession() async {
    final snapshot = _snapshot();
    final active = snapshot.activeTrainingSession;
    if (active == null) return null;
    final recovered = active.recoverAt(_clock());
    if (recovered != active) {
      await _storage.save(
        _namespace,
        snapshot.copyWith(activeTrainingSession: recovered),
      );
    }
    return recovered;
  }

  @override
  Future<void> saveActiveSession(ActiveTrainingSession session) => _storage
      .save(_namespace, _snapshot().copyWith(activeTrainingSession: session));

  @override
  Future<void> clearActiveSession() => _storage.save(
    _namespace,
    _snapshot().copyWith(clearActiveTrainingSession: true),
  );

  @override
  Future<void> saveSession(TrainingSession session) {
    final snapshot = _snapshot();
    final sessions = [...snapshot.training];
    final index = sessions.indexWhere(
      (candidate) => candidate.id == session.id,
    );
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
    return _storage.save(_namespace, snapshot.copyWith(training: sessions));
  }

  @override
  Future<TrainingSession> finishActiveSession(String activeSessionId) async {
    final active = await loadActiveSession();
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
    sessions: _snapshot().training,
    exercise: exercise,
    setOrdinal: setOrdinal,
  );
}
