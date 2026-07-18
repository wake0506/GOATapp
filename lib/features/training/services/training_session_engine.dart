import '../../../models/training.dart';
import '../../../repositories/training_repository.dart';
import '../domain/active_training_session.dart';
import '../domain/training_session_state.dart';
import '../domain/training_session_state_machine.dart';

class TrainingSessionEngine {
  TrainingSessionEngine({
    required TrainingRepository repository,
    TrainingSessionStateMachine stateMachine =
        const TrainingSessionStateMachine(),
    DateTime Function()? clock,
  }) : _repository = repository,
       _stateMachine = stateMachine,
       _clock = clock ?? DateTime.now;

  final TrainingRepository _repository;
  final TrainingSessionStateMachine _stateMachine;
  final DateTime Function() _clock;

  Future<ActiveTrainingSession> startSession({
    required String activeSessionId,
    required TrainingSession draft,
  }) async {
    final transition = _stateMachine.transition(
      state: TrainingSessionState.idle,
      event: TrainingSessionEvent.startSession,
    );
    final now = _clock();
    final active = ActiveTrainingSession(
      id: activeSessionId,
      draft: draft,
      state: _acceptedState(transition),
      startedAt: now,
      updatedAt: now,
    );
    await _repository.saveActiveSession(active);
    return active;
  }

  Future<ActiveTrainingSession?> restore() async {
    final active = await _repository.loadActiveSession();
    if (active == null) return null;
    final recovered = active.recoverAt(_clock());
    if (recovered != active) await _repository.saveActiveSession(recovered);
    return recovered;
  }

  Future<ActiveTrainingSession> confirmSession() =>
      _transition(TrainingSessionEvent.confirmSession);

  Future<ActiveTrainingSession> startSet({
    required String exerciseId,
    required String setId,
  }) => _transition(
    TrainingSessionEvent.startSet,
    currentExerciseId: exerciseId,
    currentSetId: setId,
  );

  Future<ActiveTrainingSession> completeSet({
    required String setId,
    DateTime? completedAt,
  }) async {
    final active = await _requiredActive();
    final set = _findSet(active.draft, setId);
    if (set == null) throw StateError('Set $setId was not found in the draft.');
    set.completedAt = completedAt ?? _clock();
    return _transitionFrom(
      active,
      TrainingSessionEvent.completeSet,
      currentSetId: setId,
    );
  }

  Future<ActiveTrainingSession> completeSetAndStartRest({
    required String setId,
    required int durationSeconds,
    DateTime? completedAt,
  }) async {
    await completeSet(setId: setId, completedAt: completedAt);
    return startRest(setId: setId, durationSeconds: durationSeconds);
  }

  Future<ActiveTrainingSession> updateSet({
    required String setId,
    double? weight,
    int? reps,
    int? rir,
    int? restSeconds,
    bool? reachedFailure,
  }) async {
    final active = await _requiredActive();
    final set = _findSet(active.draft, setId);
    if (set == null) throw StateError('Set $setId was not found in the draft.');
    if (weight != null) set.weight = weight < 0 ? 0 : weight;
    if (reps != null) set.reps = reps < 0 ? 0 : reps;
    if (rir != null) set.rir = rir.clamp(0, 3);
    if (restSeconds != null) {
      set.restSeconds = restSeconds < 0 ? 0 : restSeconds;
    }
    if (reachedFailure != null) set.reachedFailure = reachedFailure;
    final next = active.copyWith(updatedAt: _clock());
    await _repository.saveActiveSession(next);
    return next;
  }

  Future<ActiveTrainingSession> startRest({
    required String setId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final now = _clock();
    return _transition(
      TrainingSessionEvent.startRest,
      currentSetId: setId,
      rest: RestState(
        setId: setId,
        restStartedAt: now,
        restDurationSeconds: durationSeconds,
      ),
    );
  }

  Future<ActiveTrainingSession> updateRestDuration({
    required int durationSeconds,
  }) async {
    if (durationSeconds < 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final active = await _requiredActive();
    final rest = active.rest;
    if (active.state != TrainingSessionState.resting || rest == null) {
      throw StateError('No active rest timer.');
    }
    final now = _clock();
    final expectedEnd = rest.restStartedAt.add(
      Duration(seconds: durationSeconds),
    );
    if (!expectedEnd.isAfter(now)) return restFinished();
    final updated = active.copyWith(
      rest: rest.copyWith(
        restDurationSeconds: durationSeconds,
        restExpectedEndAt: expectedEnd,
      ),
      updatedAt: now,
    );
    await _repository.saveActiveSession(updated);
    return updated;
  }

  Future<ActiveTrainingSession> skipRest() =>
      _transition(TrainingSessionEvent.skipRest, clearRest: true);

  Future<ActiveTrainingSession> restFinished() =>
      _transition(TrainingSessionEvent.restFinished, clearRest: true);

  Future<ActiveTrainingSession> nextSet() => _transition(
    TrainingSessionEvent.nextSet,
    clearRest: true,
    clearCurrentSetId: true,
  );

  Future<ActiveTrainingSession> pause() async {
    final active = await _requiredActive();
    return _transitionFrom(
      active,
      TrainingSessionEvent.pause,
      pausedAt: _clock(),
      resumeState: active.state,
    );
  }

  Future<ActiveTrainingSession> resume() => _transition(
    TrainingSessionEvent.resume,
    clearPausedAt: true,
    clearResumeState: true,
  );

  Future<ActiveTrainingSession> replaceExercise({
    required String originalExerciseId,
    required TrainingExercise replacement,
  }) async {
    final active = await _requiredActive();
    final original = active.draft.exercises
        .where((exercise) => exercise.exerciseId == originalExerciseId)
        .firstOrNull;
    if (original == null) {
      throw StateError(
        'Exercise $originalExerciseId was not found in the draft.',
      );
    }
    original.status = TrainingExerciseStatus.replaced;
    replacement
      ..substitutedFromExerciseId = originalExerciseId
      ..status = TrainingExerciseStatus.planned
      ..orderIndex = active.draft.exercises.length;
    active.draft.exercises.add(replacement);
    return _transitionFrom(
      active,
      TrainingSessionEvent.replaceExercise,
      currentExerciseId: replacement.exerciseId,
      clearCurrentSetId: true,
    );
  }

  Future<TrainingSession> finishSession() async {
    final active = await _requiredActive();
    for (final exercise in active.draft.exercises) {
      exercise.sets.removeWhere((set) => set.completedAt == null);
    }
    active.draft.exercises.removeWhere((exercise) => exercise.sets.isEmpty);
    final finished = await _transitionFrom(
      active,
      TrainingSessionEvent.finishSession,
    );
    return _repository.finishActiveSession(finished.id);
  }

  Future<ActiveTrainingSession> _transition(
    TrainingSessionEvent event, {
    String? currentExerciseId,
    String? currentSetId,
    RestState? rest,
    DateTime? pausedAt,
    TrainingSessionState? resumeState,
    bool clearRest = false,
    bool clearCurrentSetId = false,
    bool clearPausedAt = false,
    bool clearResumeState = false,
  }) async => _transitionFrom(
    await _requiredActive(),
    event,
    currentExerciseId: currentExerciseId,
    currentSetId: currentSetId,
    rest: rest,
    pausedAt: pausedAt,
    resumeState: resumeState,
    clearRest: clearRest,
    clearCurrentSetId: clearCurrentSetId,
    clearPausedAt: clearPausedAt,
    clearResumeState: clearResumeState,
  );

  Future<ActiveTrainingSession> _transitionFrom(
    ActiveTrainingSession active,
    TrainingSessionEvent event, {
    String? currentExerciseId,
    String? currentSetId,
    RestState? rest,
    DateTime? pausedAt,
    TrainingSessionState? resumeState,
    bool clearRest = false,
    bool clearCurrentSetId = false,
    bool clearPausedAt = false,
    bool clearResumeState = false,
  }) async {
    final transition = _stateMachine.transition(
      state: active.state,
      event: event,
      resumeState: active.resumeState,
    );
    final next = active.copyWith(
      state: _acceptedState(transition),
      currentExerciseId: currentExerciseId,
      currentSetId: currentSetId,
      rest: rest,
      pausedAt: pausedAt,
      resumeState: resumeState,
      clearRest: clearRest,
      clearCurrentSetId: clearCurrentSetId,
      clearPausedAt: clearPausedAt,
      clearResumeState: clearResumeState,
      updatedAt: _clock(),
    );
    await _repository.saveActiveSession(next);
    return next;
  }

  Future<ActiveTrainingSession> _requiredActive() async {
    final active = await _repository.loadActiveSession();
    if (active == null) throw StateError('No active training session.');
    return active;
  }

  TrainingSessionState _acceptedState(TrainingStateTransition transition) {
    if (transition.isAccepted) return transition.to;
    throw StateError(
      transition.reason ?? 'Training state transition rejected.',
    );
  }

  SetRecord? _findSet(TrainingSession draft, String setId) {
    for (final exercise in draft.exercises) {
      for (final set in exercise.sets) {
        if (set.id == setId) return set;
      }
    }
    return null;
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
