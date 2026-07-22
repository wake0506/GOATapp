import '../../../models/training.dart';
import '../../../repositories/training_repository.dart';
import '../domain/active_training_session.dart';
import '../domain/training_session_state.dart';
import '../domain/training_session_state_machine.dart';
import 'superset_service.dart';
import 'warmup_suggestion_service.dart';

class TrainingSessionEngine {
  TrainingSessionEngine({
    required TrainingRepository repository,
    TrainingSessionStateMachine stateMachine =
        const TrainingSessionStateMachine(),
    SupersetService supersetService = const SupersetService(),
    DateTime Function()? clock,
  }) : _repository = repository,
       _stateMachine = stateMachine,
       _supersetService = supersetService,
       _clock = clock ?? DateTime.now;

  final TrainingRepository _repository;
  final TrainingSessionStateMachine _stateMachine;
  final SupersetService _supersetService;
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
    var recovered = active.recoverAt(_clock());
    if (recovered != active) await _repository.saveActiveSession(recovered);
    if (recovered.state == TrainingSessionState.setCompleted &&
        recovered.currentExerciseId != null &&
        recovered.currentSetId != null) {
      final partner = _supersetService.partnerAfterCompletedSet(
        session: recovered.draft,
        exerciseId: recovered.currentExerciseId!,
        setId: recovered.currentSetId!,
      );
      if (partner != null) {
        recovered = await _transitionFrom(
          recovered,
          TrainingSessionEvent.nextSet,
          clearRest: true,
          clearCurrentSetId: true,
        );
        recovered = await _transitionFrom(
          recovered,
          TrainingSessionEvent.startSet,
          currentExerciseId: partner.exerciseId,
          currentSetId: partner.setId,
        );
      }
    }
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

  Future<ActiveTrainingSession> completeSetForFlow({
    required String setId,
    DateTime? completedAt,
  }) async {
    final before = await _requiredActive();
    final exercise = _findExerciseForSet(before.draft, setId);
    final set = _findSet(before.draft, setId);
    if (exercise?.exerciseId == null || set == null) {
      throw StateError('Set $setId was not found in the draft.');
    }
    var completed = await completeSet(setId: setId, completedAt: completedAt);
    final partner = _supersetService.partnerAfterCompletedSet(
      session: completed.draft,
      exerciseId: exercise!.exerciseId!,
      setId: setId,
    );
    if (partner != null) {
      completed = await nextSet();
      return startSet(exerciseId: partner.exerciseId, setId: partner.setId);
    }
    if (_hasPendingSets(completed.draft)) {
      return startRest(
        setId: setId,
        durationSeconds: set.restSeconds > 0 ? set.restSeconds : 90,
      );
    }
    return completed;
  }

  Future<ActiveTrainingSession> startNextAvailableSet() async {
    final active = await _requiredActive();
    if (active.state != TrainingSessionState.readyForNextSet) {
      throw StateError('The session is not ready for the next set.');
    }
    SupersetSetTarget? target;
    if (active.currentExerciseId != null && active.currentSetId != null) {
      target = _supersetService.firstSetAfterRest(
        session: active.draft,
        exerciseId: active.currentExerciseId!,
        setId: active.currentSetId!,
      );
    }
    target ??= _nextPendingTarget(active);
    if (target == null) return active;
    return startSet(exerciseId: target.exerciseId, setId: target.setId);
  }

  Future<ActiveTrainingSession> updateSet({
    required String setId,
    double? weight,
    int? reps,
    int? rir,
    int? restSeconds,
    bool? reachedFailure,
    TrainingSetType? setType,
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
    if (setType != null) set.setType = setType;
    final next = active.copyWith(updatedAt: _clock());
    await _repository.saveActiveSession(next);
    return next;
  }

  Future<ActiveTrainingSession> applySuggestedWeight({
    required String exerciseId,
    required double weightKg,
  }) async {
    if (!weightKg.isFinite || weightKg < 0) {
      throw ArgumentError.value(weightKg, 'weightKg');
    }
    final active = await _requiredActive();
    final exercise = active.draft.exercises
        .where((candidate) => candidate.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null) {
      throw StateError('Exercise $exerciseId was not found in the draft.');
    }
    SetRecord? targetSet;
    if (active.currentSetId != null) {
      targetSet = exercise.sets
          .where(
            (set) =>
                set.id == active.currentSetId &&
                set.completedAt == null &&
                !set.replacementPlaceholder &&
                _isWorkingEquivalent(set),
          )
          .firstOrNull;
    }
    targetSet ??= exercise.sets
        .where(
          (set) =>
              set.completedAt == null &&
              !set.replacementPlaceholder &&
              _isWorkingEquivalent(set),
        )
        .firstOrNull;
    if (targetSet == null) {
      throw StateError('No pending working set can accept the suggestion.');
    }
    targetSet.weight = weightKg;
    return _saveDraftChange(active);
  }

  bool _isWorkingEquivalent(SetRecord set) =>
      set.resolvedSetType == TrainingSetType.working ||
      set.resolvedSetType == TrainingSetType.superset;

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

  Future<ActiveTrainingSession> updateExerciseRestDuration({
    required String exerciseId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final active = await _requiredActive();
    final exercise = active.draft.exercises
        .where((candidate) => candidate.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null) {
      throw StateError('Exercise $exerciseId was not found in the draft.');
    }
    for (final set in exercise.sets) {
      if (!set.replacementPlaceholder) set.restSeconds = durationSeconds;
    }
    return _saveDraftChange(active);
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
      ..orderIndex = original.orderIndex
      ..supersetGroupId = original.supersetGroupId;
    for (
      var index = 0;
      index < original.sets.length && index < replacement.sets.length;
      index++
    ) {
      if (original.sets[index].completedAt != null) {
        replacement.sets[index].replacementPlaceholder = true;
      }
    }
    if (replacement.supersetGroupId != null) {
      for (final set in replacement.sets) {
        if (set.completedAt == null) set.setType = TrainingSetType.superset;
      }
    }
    active.draft.exercises.add(replacement);
    final currentOrdinal = original.sets.indexWhere(
      (set) => set.id == active.currentSetId,
    );
    final mappedCurrentSetId =
        currentOrdinal >= 0 && currentOrdinal < replacement.sets.length
        ? replacement.sets[currentOrdinal].id
        : null;
    return _transitionFrom(
      active,
      TrainingSessionEvent.replaceExercise,
      currentExerciseId: replacement.exerciseId,
      currentSetId: mappedCurrentSetId,
      clearCurrentSetId: mappedCurrentSetId == null,
    );
  }

  Future<ActiveTrainingSession> pairSuperset({
    required String firstExerciseId,
    required String secondExerciseId,
  }) async {
    final active = await _requiredActive();
    _supersetService.pair(
      session: active.draft,
      firstExerciseId: firstExerciseId,
      secondExerciseId: secondExerciseId,
    );
    return _saveDraftChange(active);
  }

  Future<ActiveTrainingSession> addSupersetPartner({
    required String firstExerciseId,
    required TrainingExercise partner,
  }) async {
    final active = await _requiredActive();
    if (partner.exerciseId == null || partner.exerciseId == firstExerciseId) {
      throw ArgumentError('A different partner exercise is required.');
    }
    final existing = active.draft.exercises.any(
      (exercise) =>
          exercise.status != TrainingExerciseStatus.replaced &&
          exercise.exerciseId == partner.exerciseId,
    );
    if (existing) {
      throw StateError('The partner exercise is already in this session.');
    }
    partner
      ..status = TrainingExerciseStatus.planned
      ..orderIndex = active.draft.exercises.length;
    active.draft.exercises.add(partner);
    _supersetService.pair(
      session: active.draft,
      firstExerciseId: firstExerciseId,
      secondExerciseId: partner.exerciseId!,
    );
    return _saveDraftChange(active);
  }

  Future<ActiveTrainingSession> clearSuperset({
    required String exerciseId,
  }) async {
    final active = await _requiredActive();
    _supersetService.clear(session: active.draft, exerciseId: exerciseId);
    return _saveDraftChange(active);
  }

  Future<ActiveTrainingSession> insertWarmupSuggestions({
    required String exerciseId,
    required List<WarmupSuggestion> suggestions,
  }) async {
    final active = await _requiredActive();
    final exercise = active.draft.exercises
        .where(
          (candidate) =>
              candidate.exerciseId == exerciseId &&
              candidate.status != TrainingExerciseStatus.replaced,
        )
        .firstOrNull;
    if (exercise == null) throw StateError('Exercise was not found.');
    final hasCompletedWorkingSet = exercise.sets.any(
      (set) =>
          set.completedAt != null &&
          set.resolvedSetType == TrainingSetType.working,
    );
    if (hasCompletedWorkingSet) {
      throw StateError('Warm-up sets cannot be inserted into past history.');
    }
    if (suggestions.isEmpty) return active;
    final existing = exercise.sets
        .where((set) => set.resolvedSetType == TrainingSetType.warmup)
        .map((set) => '${set.weight.toStringAsFixed(2)}:${set.reps}')
        .toSet();
    final now = _clock().microsecondsSinceEpoch;
    final additions = suggestions
        .where(
          (item) =>
              existing.add('${item.weight.toStringAsFixed(2)}:${item.reps}'),
        )
        .map(
          (item) => SetRecord(
            id: '${active.id}-$exerciseId-warmup-$now-${item.order}',
            weight: item.weight,
            reps: item.reps,
            restSeconds: 60,
            setType: TrainingSetType.warmup,
          ),
        )
        .toList();
    if (additions.isEmpty) return active;
    final firstWorkingIndex = exercise.sets.indexWhere(
      (set) => set.resolvedSetType == TrainingSetType.working,
    );
    exercise.sets.insertAll(
      firstWorkingIndex < 0 ? 0 : firstWorkingIndex,
      additions,
    );
    var next = active.copyWith(updatedAt: _clock());
    if (active.currentExerciseId == exerciseId &&
        active.state == TrainingSessionState.activeSet) {
      next = next.copyWith(currentSetId: additions.first.id);
    }
    await _repository.saveActiveSession(next);
    return next;
  }

  Future<TrainingSession> finishSession() async {
    final active = await _requiredActive();
    for (final exercise in active.draft.exercises) {
      exercise.sets.removeWhere(
        (set) => set.completedAt == null || set.replacementPlaceholder,
      );
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
    if (event == TrainingSessionEvent.startSet &&
        currentExerciseId != null &&
        currentSetId != null) {
      _copyPreviousSetPerformance(
        active.draft,
        exerciseId: currentExerciseId,
        setId: currentSetId,
      );
    }
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

  Future<ActiveTrainingSession> _saveDraftChange(
    ActiveTrainingSession active,
  ) async {
    final next = active.copyWith(updatedAt: _clock());
    await _repository.saveActiveSession(next);
    return next;
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

  TrainingExercise? _findExerciseForSet(TrainingSession draft, String setId) =>
      draft.exercises
          .where((exercise) => exercise.sets.any((set) => set.id == setId))
          .firstOrNull;

  void _copyPreviousSetPerformance(
    TrainingSession draft, {
    required String exerciseId,
    required String setId,
  }) {
    final exercise = draft.exercises
        .where((candidate) => candidate.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null) return;
    final targetIndex = exercise.sets.indexWhere((set) => set.id == setId);
    if (targetIndex <= 0) return;
    final target = exercise.sets[targetIndex];
    final previous = exercise.sets
        .take(targetIndex)
        .where(
          (set) =>
              set.completedAt != null &&
              !set.replacementPlaceholder &&
              set.resolvedSetType == target.resolvedSetType,
        )
        .lastOrNull;
    if (previous == null) return;
    if (target.weight == 0) target.weight = previous.weight;
    if (target.reps == 0) target.reps = previous.reps;
  }

  bool _hasPendingSets(TrainingSession draft) => draft.exercises.any(
    (exercise) =>
        exercise.status != TrainingExerciseStatus.replaced &&
        exercise.sets.any(
          (set) => set.completedAt == null && !set.replacementPlaceholder,
        ),
  );

  SupersetSetTarget? _nextPendingTarget(ActiveTrainingSession active) {
    final exercises = active.draft.exercises
        .where((exercise) => exercise.status != TrainingExerciseStatus.replaced)
        .toList();
    final currentIndex = exercises.indexWhere(
      (exercise) => exercise.exerciseId == active.currentExerciseId,
    );
    final ordered = currentIndex < 0
        ? exercises
        : [...exercises.skip(currentIndex), ...exercises.take(currentIndex)];
    for (final exercise in ordered) {
      final set = exercise.sets
          .where(
            (candidate) =>
                candidate.completedAt == null &&
                !candidate.replacementPlaceholder,
          )
          .firstOrNull;
      if (exercise.exerciseId != null && set?.id != null) {
        return SupersetSetTarget(
          exerciseId: exercise.exerciseId!,
          setId: set!.id!,
        );
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
