import '../../../models/training.dart';
import '../../../models/rest_prescription.dart';
import '../../../repositories/training_repository.dart';
import '../domain/active_training_session.dart';
import '../domain/training_session_state.dart';
import '../domain/training_session_state_machine.dart';
import '../models/exercise_rest_profile_catalog.dart';
import 'rest_prescription_engine.dart';
import 'superset_service.dart';
import 'warmup_suggestion_service.dart';

class TrainingSessionEngine {
  TrainingSessionEngine({
    required TrainingRepository repository,
    TrainingSessionStateMachine stateMachine =
        const TrainingSessionStateMachine(),
    SupersetService supersetService = const SupersetService(),
    RestPrescriptionEngine restPrescriptionEngine =
        const RestPrescriptionEngine(),
    DateTime Function()? clock,
  }) : _repository = repository,
       _stateMachine = stateMachine,
       _supersetService = supersetService,
       _restPrescriptionEngine = restPrescriptionEngine,
       _clock = clock ?? DateTime.now;

  final TrainingRepository _repository;
  final TrainingSessionStateMachine _stateMachine;
  final SupersetService _supersetService;
  final RestPrescriptionEngine _restPrescriptionEngine;
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
    if (!_hasPendingSets(completed.draft)) return completed;

    final nextTarget = _nextPendingTarget(completed);
    if (nextTarget == null) return completed;
    final nextExercise = _findExercise(completed.draft, nextTarget.exerciseId);
    final hasPendingInCurrent = exercise.sets.any(
      (candidate) =>
          candidate.completedAt == null && !candidate.replacementPlaceholder,
    );
    final supersetMembers = _supersetService.membersFor(
      completed.draft,
      exercise.exerciseId!,
    );
    final isSupersetCycle =
        supersetMembers.length == 2 &&
        supersetMembers.last.exerciseId == exercise.exerciseId &&
        set.resolvedSetType == TrainingSetType.superset;
    final partnerExercise = isSupersetCycle ? supersetMembers.first : null;
    final partnerSet = partnerExercise == null
        ? null
        : _setAtMatchingOrdinal(
            source: exercise,
            sourceSetId: setId,
            target: partnerExercise,
          );
    final isFinalWarmup =
        set.resolvedSetType == TrainingSetType.warmup &&
        !exercise.sets
            .skipWhile((candidate) => candidate.id != setId)
            .skip(1)
            .any(
              (candidate) =>
                  candidate.completedAt == null &&
                  candidate.resolvedSetType == TrainingSetType.warmup,
            );
    final recommendation = _restPrescriptionEngine.recommend(
      RestPrescriptionRequest(
        currentProfile: ExerciseRestProfileCatalog.find(exercise.exerciseId),
        setType: set.resolvedSetType,
        rir: set.rir,
        reachedFailure: set.reachedFailure == true,
        currentWeight: set.weight,
        referenceWorkingWeight: _referenceWorkingWeight(exercise),
        isFinalWarmup: isFinalWarmup,
        isLastSetOfExercise: !hasPendingInCurrent,
        currentBodyPart: exercise.bodyPart,
        nextProfile: ExerciseRestProfileCatalog.find(nextExercise?.exerciseId),
        nextBodyPart: nextExercise?.bodyPart,
        nextExerciseId: nextExercise?.exerciseId,
        prescription:
            exercise.restPrescription ?? const RestPrescription.recommended(),
        sessionExerciseOverrideSeconds:
            completed.exerciseRestOverrides[exercise.exerciseId],
        isSupersetCycle: isSupersetCycle,
        supersetPartnerProfile: ExerciseRestProfileCatalog.find(
          partnerExercise?.exerciseId,
        ),
        supersetPartnerPrescription: partnerExercise?.restPrescription,
        supersetPartnerFatigueModifier: partnerSet == null
            ? 0
            : _restPrescriptionEngine.fatigueModifier(
                setType: partnerSet.resolvedSetType,
                rir: partnerSet.rir,
                reachedFailure: partnerSet.reachedFailure == true,
              ),
        supersetGroupOverrideSeconds: exercise.supersetGroupId == null
            ? null
            : completed.supersetRestOverrides[exercise.supersetGroupId],
      ),
    );
    if (!recommendation.shouldStartTimer) return completed;
    return startRest(
      setId: setId,
      durationSeconds: recommendation.plannedSeconds,
      recommendation: recommendation,
    );
  }

  Future<ActiveTrainingSession> startNextAvailableSet() async {
    var active = await _requiredActive();
    if (active.state != TrainingSessionState.readyForNextSet) {
      throw StateError('The session is not ready for the next set.');
    }
    if (active.rest != null) {
      active = _finalizeActualRest(active, at: _clock(), clearRest: true);
      await _repository.saveActiveSession(active);
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
    return _transitionFrom(
      active,
      TrainingSessionEvent.startSet,
      currentExerciseId: target.exerciseId,
      currentSetId: target.setId,
    );
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
    RestRecommendation? recommendation,
  }) async {
    if (durationSeconds < 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final now = _clock();
    final active = await _requiredActive();
    final set = _findSet(active.draft, setId);
    if (set == null) throw StateError('Set $setId was not found in the draft.');
    final resolvedRecommendation =
        recommendation ??
        RestRecommendation(
          recommendedSeconds: durationSeconds,
          plannedSeconds: durationSeconds,
          baseSeconds: durationSeconds,
          modifierSeconds: 0,
          source: RestSource.legacyFallback,
          reasonCodes: const [],
          transitionType: RestTransitionType.betweenSets,
        );
    _recordRestPlan(set, resolvedRecommendation);
    return _transitionFrom(
      active,
      TrainingSessionEvent.startRest,
      currentSetId: setId,
      rest: RestState(
        setId: setId,
        restStartedAt: now,
        restDurationSeconds: durationSeconds,
        recommendation: resolvedRecommendation,
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
    final updated = active.copyWith(
      rest: rest.copyWith(
        restDurationSeconds: durationSeconds,
        restExpectedEndAt: expectedEnd,
        recommendation: _withPlannedSeconds(
          rest.recommendation,
          durationSeconds,
        ),
      ),
      updatedAt: now,
    );
    final set = _findSet(updated.draft, rest.setId);
    if (set != null) {
      set
        ..restSeconds = durationSeconds
        ..plannedRestSeconds = durationSeconds;
    }
    await _repository.saveActiveSession(updated);
    if (!expectedEnd.isAfter(now)) {
      return _transitionFrom(updated, TrainingSessionEvent.restFinished);
    }
    return updated;
  }

  Future<ActiveTrainingSession> updateExerciseRestDuration({
    required String exerciseId,
    required int durationSeconds,
  }) => setExerciseRestOverride(
    exerciseId: exerciseId,
    durationSeconds: durationSeconds,
  );

  Future<ActiveTrainingSession> setExerciseRestOverride({
    required String exerciseId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 15 || durationSeconds > 600) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final active = await _requiredActive();
    final exercise = active.draft.exercises
        .where((candidate) => candidate.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null) {
      throw StateError('Exercise $exerciseId was not found in the draft.');
    }
    return _saveDraftChange(
      active.copyWith(
        exerciseRestOverrides: Map.unmodifiable({
          ...active.exerciseRestOverrides,
          exerciseId: durationSeconds,
        }),
      ),
    );
  }

  Future<ActiveTrainingSession> clearExerciseRestOverride({
    required String exerciseId,
  }) async {
    final active = await _requiredActive();
    final overrides = {...active.exerciseRestOverrides}..remove(exerciseId);
    return _saveDraftChange(
      active.copyWith(exerciseRestOverrides: Map.unmodifiable(overrides)),
    );
  }

  Future<ActiveTrainingSession> setSupersetRestOverride({
    required String groupId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 15 || durationSeconds > 600) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final active = await _requiredActive();
    return _saveDraftChange(
      active.copyWith(
        supersetRestOverrides: Map.unmodifiable({
          ...active.supersetRestOverrides,
          groupId: durationSeconds,
        }),
      ),
    );
  }

  Future<ActiveTrainingSession> clearSupersetRestOverride({
    required String groupId,
  }) async {
    final active = await _requiredActive();
    final overrides = {...active.supersetRestOverrides}..remove(groupId);
    return _saveDraftChange(
      active.copyWith(supersetRestOverrides: Map.unmodifiable(overrides)),
    );
  }

  Future<ActiveTrainingSession> setCurrentRestOverride({
    required String exerciseId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 15 || durationSeconds > 600) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    var active = await _requiredActive();
    final rest = active.rest;
    if (active.state != TrainingSessionState.resting || rest == null) {
      throw StateError('No active rest timer.');
    }
    final recommendation =
        rest.recommendation ??
        RestRecommendation(
          recommendedSeconds: rest.restDurationSeconds,
          plannedSeconds: rest.restDurationSeconds,
          baseSeconds: rest.restDurationSeconds,
          modifierSeconds: 0,
          source: RestSource.legacyFallback,
          reasonCodes: const [],
          transitionType: RestTransitionType.betweenSets,
        );
    final exercise = _findExercise(active.draft, exerciseId);
    final isSupersetCycle =
        recommendation.transitionType == RestTransitionType.supersetCycle &&
        exercise?.supersetGroupId != null;
    if (isSupersetCycle) {
      active = active.copyWith(
        supersetRestOverrides: Map.unmodifiable({
          ...active.supersetRestOverrides,
          exercise!.supersetGroupId!: durationSeconds,
        }),
      );
    } else {
      active = active.copyWith(
        exerciseRestOverrides: Map.unmodifiable({
          ...active.exerciseRestOverrides,
          exerciseId: durationSeconds,
        }),
      );
    }
    final updatedRecommendation = RestRecommendation(
      recommendedSeconds: recommendation.recommendedSeconds,
      plannedSeconds: durationSeconds,
      baseSeconds: recommendation.baseSeconds,
      modifierSeconds: recommendation.modifierSeconds,
      source: isSupersetCycle
          ? RestSource.supersetOverride
          : RestSource.sessionExerciseOverride,
      reasonCodes: {
        ...recommendation.reasonCodes,
        RestReasonCode.sessionOverride,
      }.toList(growable: false),
      transitionType: recommendation.transitionType,
      policyVersion: recommendation.policyVersion,
      isUserOverridden: true,
      nextExerciseId: recommendation.nextExerciseId,
    );
    return _saveCurrentRest(
      active,
      durationSeconds: durationSeconds,
      recommendation: updatedRecommendation,
    );
  }

  Future<ActiveTrainingSession> restoreCurrentRestRecommendation({
    required String exerciseId,
  }) async {
    var active = await _requiredActive();
    final rest = active.rest;
    final recommendation = rest?.recommendation;
    if (active.state != TrainingSessionState.resting ||
        rest == null ||
        recommendation == null) {
      throw StateError('No active prescribed rest timer.');
    }
    final exercise = _findExercise(active.draft, exerciseId);
    final isSupersetCycle =
        recommendation.transitionType == RestTransitionType.supersetCycle &&
        exercise?.supersetGroupId != null;
    if (isSupersetCycle) {
      final overrides = {...active.supersetRestOverrides}
        ..remove(exercise!.supersetGroupId);
      active = active.copyWith(
        supersetRestOverrides: Map.unmodifiable(overrides),
      );
    } else {
      final overrides = {...active.exerciseRestOverrides}..remove(exerciseId);
      active = active.copyWith(
        exerciseRestOverrides: Map.unmodifiable(overrides),
      );
    }
    final fixed = isSupersetCycle
        ? null
        : exercise?.restPrescription?.validFixedSeconds;
    final planned = fixed ?? recommendation.recommendedSeconds;
    final reasons = recommendation.reasonCodes
        .where((reason) => reason != RestReasonCode.sessionOverride)
        .toSet()
        .toList(growable: true);
    if (fixed != null && !reasons.contains(RestReasonCode.userFixed)) {
      reasons.add(RestReasonCode.userFixed);
    }
    final updatedRecommendation = RestRecommendation(
      recommendedSeconds: recommendation.recommendedSeconds,
      plannedSeconds: planned,
      baseSeconds: recommendation.baseSeconds,
      modifierSeconds: fixed == null ? recommendation.modifierSeconds : 0,
      source: fixed != null
          ? RestSource.templateFixed
          : RestSource.exerciseProfile,
      reasonCodes: reasons,
      transitionType: recommendation.transitionType,
      policyVersion: recommendation.policyVersion,
      nextExerciseId: recommendation.nextExerciseId,
    );
    return _saveCurrentRest(
      active,
      durationSeconds: planned,
      recommendation: updatedRecommendation,
    );
  }

  Future<ActiveTrainingSession> skipRest() async {
    final active = await _requiredActive();
    final finalized = _finalizeActualRest(active, at: _clock());
    return _transitionFrom(
      finalized,
      TrainingSessionEvent.skipRest,
      clearRest: true,
    );
  }

  Future<ActiveTrainingSession> restFinished() =>
      _transition(TrainingSessionEvent.restFinished);

  Future<ActiveTrainingSession> nextSet() async {
    var active = await _requiredActive();
    if (active.rest != null) {
      active = _finalizeActualRest(active, at: _clock());
    }
    return _transitionFrom(
      active,
      TrainingSessionEvent.nextSet,
      clearRest: true,
      clearCurrentSetId: true,
    );
  }

  Future<ActiveTrainingSession> extendCurrentRest({int seconds = 30}) async {
    if (seconds <= 0) throw ArgumentError.value(seconds, 'seconds');
    final active = await _requiredActive();
    final rest = active.rest;
    if (active.state != TrainingSessionState.resting || rest == null) {
      throw StateError('No active rest timer.');
    }
    return updateRestDuration(
      durationSeconds: (rest.restDurationSeconds + seconds).clamp(15, 600),
    );
  }

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
      ..supersetGroupId = original.supersetGroupId
      ..restPrescription ??= original.restPrescription;
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

  Future<ActiveTrainingSession> adoptRecommendedExercise({
    required TrainingExercise recommendation,
  }) async {
    final exerciseId = recommendation.exerciseId?.trim();
    if (exerciseId == null || exerciseId.isEmpty) {
      throw ArgumentError('A stable exercise ID is required.');
    }
    final active = await _requiredActive();
    var target = active.draft.exercises
        .where(
          (exercise) =>
              exercise.status != TrainingExerciseStatus.replaced &&
              exercise.exerciseId == exerciseId,
        )
        .firstOrNull;
    if (target == null) {
      recommendation
        ..status = TrainingExerciseStatus.planned
        ..orderIndex = active.draft.exercises.length;
      active.draft.exercises.add(recommendation);
      target = recommendation;
    }
    final hasPendingSet = target.sets.any(
      (set) => set.completedAt == null && !set.replacementPlaceholder,
    );
    if (!hasPendingSet) {
      throw StateError('The recommended exercise has no pending sets.');
    }
    final next = active.copyWith(
      currentExerciseId: exerciseId,
      clearCurrentSetId: true,
      updatedAt: _clock(),
    );
    await _repository.saveActiveSession(next);
    return next;
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
    var active = await _requiredActive();
    if (active.rest != null) {
      active = _finalizeActualRest(active, at: _clock(), clearRest: true);
      await _repository.saveActiveSession(active);
    }
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

  TrainingExercise? _findExercise(TrainingSession draft, String exerciseId) =>
      draft.exercises
          .where(
            (exercise) =>
                exercise.exerciseId == exerciseId &&
                exercise.status != TrainingExerciseStatus.replaced,
          )
          .firstOrNull;

  SetRecord? _setAtMatchingOrdinal({
    required TrainingExercise source,
    required String sourceSetId,
    required TrainingExercise target,
  }) {
    final ordinal = source.sets.indexWhere((set) => set.id == sourceSetId);
    if (ordinal < 0 || ordinal >= target.sets.length) return null;
    return target.sets[ordinal];
  }

  double? _referenceWorkingWeight(TrainingExercise exercise) {
    final weights = exercise.sets
        .where(
          (set) =>
              set.resolvedSetType != TrainingSetType.warmup && set.weight > 0,
        )
        .map((set) => set.weight)
        .toList(growable: false);
    if (weights.isEmpty) return null;
    return weights.reduce((left, right) => left > right ? left : right);
  }

  void _recordRestPlan(SetRecord set, RestRecommendation recommendation) {
    set
      ..recommendedRestSeconds = recommendation.recommendedSeconds
      ..plannedRestSeconds = recommendation.plannedSeconds
      ..restSeconds = recommendation.plannedSeconds
      ..restPolicyVersion = recommendation.policyVersion
      ..restSource = recommendation.source;
  }

  Future<ActiveTrainingSession> _saveCurrentRest(
    ActiveTrainingSession active, {
    required int durationSeconds,
    required RestRecommendation recommendation,
  }) async {
    final rest = active.rest;
    if (rest == null) throw StateError('No active rest timer.');
    final updated = active.copyWith(
      rest: rest.copyWith(
        restDurationSeconds: durationSeconds,
        restExpectedEndAt: rest.restStartedAt.add(
          Duration(seconds: durationSeconds),
        ),
        recommendation: recommendation,
      ),
      updatedAt: _clock(),
    );
    final set = _findSet(updated.draft, rest.setId);
    if (set != null) _recordRestPlan(set, recommendation);
    await _repository.saveActiveSession(updated);
    return updated;
  }

  ActiveTrainingSession _finalizeActualRest(
    ActiveTrainingSession active, {
    required DateTime at,
    bool clearRest = false,
  }) {
    final rest = active.rest;
    if (rest == null) return active;
    final elapsed = at.difference(rest.restStartedAt).inSeconds;
    final set = _findSet(active.draft, rest.setId);
    if (set != null) set.actualRestSeconds = elapsed < 0 ? 0 : elapsed;
    return active.copyWith(clearRest: clearRest, updatedAt: at);
  }

  RestRecommendation? _withPlannedSeconds(
    RestRecommendation? recommendation,
    int seconds,
  ) {
    if (recommendation == null) return null;
    return RestRecommendation(
      recommendedSeconds: recommendation.recommendedSeconds,
      plannedSeconds: seconds,
      baseSeconds: recommendation.baseSeconds,
      modifierSeconds: recommendation.modifierSeconds,
      source: recommendation.source,
      reasonCodes: recommendation.reasonCodes,
      transitionType: recommendation.transitionType,
      policyVersion: recommendation.policyVersion,
      isUserOverridden: recommendation.isUserOverridden,
      nextExerciseId: recommendation.nextExerciseId,
      shouldStartTimer: recommendation.shouldStartTimer,
    );
  }

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
