import 'dart:math' as math;

import '../../../models/rest_prescription.dart';
import '../domain/training_session_state.dart';

class RestPrescriptionRequest {
  const RestPrescriptionRequest({
    this.currentProfile,
    this.setType = TrainingSetType.working,
    this.rir,
    this.reachedFailure = false,
    this.currentWeight,
    this.referenceWorkingWeight,
    this.isFinalWarmup = false,
    this.isLastSetOfExercise = false,
    this.isLastSetOfSession = false,
    this.currentBodyPart,
    this.nextProfile,
    this.nextBodyPart,
    this.nextExerciseId,
    this.prescription = const RestPrescription.recommended(),
    this.sessionExerciseOverrideSeconds,
    this.isSupersetCycle = false,
    this.supersetPartnerProfile,
    this.supersetPartnerPrescription,
    this.supersetPartnerFatigueModifier = 0,
    this.supersetGroupOverrideSeconds,
  });

  final ExerciseRestProfile? currentProfile;
  final TrainingSetType setType;
  final int? rir;
  final bool reachedFailure;
  final double? currentWeight;
  final double? referenceWorkingWeight;
  final bool isFinalWarmup;
  final bool isLastSetOfExercise;
  final bool isLastSetOfSession;
  final String? currentBodyPart;
  final ExerciseRestProfile? nextProfile;
  final String? nextBodyPart;
  final String? nextExerciseId;
  final RestPrescription prescription;
  final int? sessionExerciseOverrideSeconds;
  final bool isSupersetCycle;
  final ExerciseRestProfile? supersetPartnerProfile;
  final RestPrescription? supersetPartnerPrescription;
  final int supersetPartnerFatigueModifier;
  final int? supersetGroupOverrideSeconds;
}

class RestPrescriptionEngine {
  const RestPrescriptionEngine();

  RestRecommendation recommend(RestPrescriptionRequest request) {
    if (request.isLastSetOfSession) {
      return const RestRecommendation.sessionComplete();
    }
    if (request.setType == TrainingSetType.warmup) {
      return _withExerciseOverride(
        _warmupRecommendation(request),
        request.sessionExerciseOverrideSeconds,
      );
    }
    if (request.isLastSetOfExercise && request.nextProfile != null) {
      return _transitionRecommendation(request);
    }
    if (request.isSupersetCycle) {
      return _supersetCycleRecommendation(request);
    }

    final base = _baseSeconds(request.currentProfile);
    final reasons = <RestReasonCode>[
      _classReason(
        request.currentProfile?.restClass ?? ExerciseRestClass.other,
      ),
    ];
    final modifier = fatigueModifier(
      setType: request.setType,
      rir: request.rir,
      reachedFailure: request.reachedFailure,
      reasonCodes: reasons,
    );
    final dynamicSeconds = _recommendedClamp(base + modifier);
    RestRecommendation recommendation;
    final fixedSeconds = request.prescription.validFixedSeconds;
    if (fixedSeconds != null) {
      recommendation = RestRecommendation(
        recommendedSeconds: base,
        plannedSeconds: fixedSeconds,
        baseSeconds: base,
        modifierSeconds: 0,
        source: RestSource.templateFixed,
        reasonCodes: [
          _classReason(
            request.currentProfile?.restClass ?? ExerciseRestClass.other,
          ),
          RestReasonCode.userFixed,
        ],
        transitionType: RestTransitionType.betweenSets,
      );
    } else {
      recommendation = RestRecommendation(
        recommendedSeconds: dynamicSeconds,
        plannedSeconds: dynamicSeconds,
        baseSeconds: base,
        modifierSeconds: modifier,
        source: request.currentProfile == null
            ? RestSource.legacyFallback
            : RestSource.exerciseProfile,
        reasonCodes: reasons,
        transitionType: RestTransitionType.betweenSets,
      );
    }
    return _withExerciseOverride(
      recommendation,
      request.sessionExerciseOverrideSeconds,
    );
  }

  int fatigueModifier({
    required TrainingSetType setType,
    int? rir,
    bool reachedFailure = false,
    List<RestReasonCode>? reasonCodes,
  }) {
    var rirModifier = 0;
    if (rir == 1) {
      rirModifier = 30;
      reasonCodes?.add(RestReasonCode.rirOne);
    } else if (rir == 0) {
      rirModifier = 60;
      reasonCodes?.add(RestReasonCode.rirZero);
    }

    var failureModifier = 0;
    if (reachedFailure) {
      failureModifier = 60;
      reasonCodes?.add(RestReasonCode.reachedFailure);
    }

    final setModifier = switch (setType) {
      TrainingSetType.drop => 30,
      TrainingSetType.amrap => 30,
      TrainingSetType.failure => 60,
      _ => 0,
    };
    if (setType == TrainingSetType.drop) {
      reasonCodes?.add(RestReasonCode.dropSet);
    } else if (setType == TrainingSetType.amrap) {
      reasonCodes?.add(RestReasonCode.amrapSet);
    } else if (setType == TrainingSetType.failure) {
      reasonCodes?.add(RestReasonCode.failureSet);
    }
    return math.max(rirModifier, math.max(failureModifier, setModifier));
  }

  RestRecommendation _warmupRecommendation(RestPrescriptionRequest request) {
    final weight = request.currentWeight;
    final reference = request.referenceWorkingWeight;
    int tierSeconds;
    RestReasonCode tierReason;
    if (weight != null && reference != null && weight >= 0 && reference > 0) {
      final ratio = weight / reference;
      if (ratio <= 0.50) {
        tierSeconds = 45;
        tierReason = RestReasonCode.warmupLowLoad;
      } else if (ratio <= 0.70) {
        tierSeconds = 60;
        tierReason = RestReasonCode.warmupMediumLoad;
      } else if (ratio <= 0.85) {
        tierSeconds = 90;
        tierReason = RestReasonCode.warmupHighLoad;
      } else {
        tierSeconds = 120;
        tierReason = RestReasonCode.warmupHighLoad;
      }
    } else {
      tierSeconds = 60;
      tierReason = RestReasonCode.warmupMediumLoad;
    }
    final preWorking = _preWorkingRecovery(request.currentProfile);
    final recommended = request.isFinalWarmup
        ? math.max(tierSeconds, preWorking)
        : tierSeconds;
    return RestRecommendation(
      recommendedSeconds: recommended,
      plannedSeconds: recommended,
      baseSeconds: tierSeconds,
      modifierSeconds: recommended - tierSeconds,
      source: request.currentProfile == null
          ? RestSource.legacyFallback
          : RestSource.exerciseProfile,
      reasonCodes: [
        tierReason,
        if (request.isFinalWarmup) RestReasonCode.finalWarmup,
      ],
      transitionType: RestTransitionType.warmup,
    );
  }

  RestRecommendation _transitionRecommendation(
    RestPrescriptionRequest request,
  ) {
    final currentBase = _baseSeconds(request.currentProfile);
    final nextBase = _baseSeconds(request.nextProfile);
    final nextClass = request.nextProfile!.restClass;
    late final int seconds;
    late final RestReasonCode detailReason;
    if (nextClass == ExerciseRestClass.olympicPower ||
        nextClass == ExerciseRestClass.heavyCompound) {
      seconds = nextBase;
      detailReason = RestReasonCode.nextHeavyExercise;
    } else if (request.currentBodyPart != null &&
        request.currentBodyPart == request.nextBodyPart) {
      seconds = math.max(90, math.min(math.max(currentBase, nextBase), 150));
      detailReason = RestReasonCode.sameBodyPartTransition;
    } else {
      seconds = 75;
      detailReason = RestReasonCode.differentBodyPartTransition;
    }
    return RestRecommendation(
      recommendedSeconds: seconds,
      plannedSeconds: seconds,
      baseSeconds: seconds,
      modifierSeconds: 0,
      source: RestSource.exerciseProfile,
      reasonCodes: [RestReasonCode.exerciseTransition, detailReason],
      transitionType: RestTransitionType.exerciseTransition,
      nextExerciseId: request.nextExerciseId,
    );
  }

  RestRecommendation _supersetCycleRecommendation(
    RestPrescriptionRequest request,
  ) {
    final currentBase = _effectiveBase(
      request.currentProfile,
      request.prescription,
    );
    final partnerBase = _effectiveBase(
      request.supersetPartnerProfile,
      request.supersetPartnerPrescription,
    );
    final base = math.max(currentBase, partnerBase);
    final reasons = <RestReasonCode>[RestReasonCode.supersetCycleRest];
    final currentModifier = fatigueModifier(
      setType: request.setType,
      rir: request.rir,
      reachedFailure: request.reachedFailure,
      reasonCodes: reasons,
    );
    final modifier = math.max(
      currentModifier,
      request.supersetPartnerFatigueModifier,
    );
    final recommended = _recommendedClamp(base + modifier);
    final override = _validUserSeconds(request.supersetGroupOverrideSeconds);
    return RestRecommendation(
      recommendedSeconds: recommended,
      plannedSeconds: override ?? recommended,
      baseSeconds: base,
      modifierSeconds: modifier,
      source: override == null
          ? RestSource.exerciseProfile
          : RestSource.supersetOverride,
      reasonCodes: [
        ...reasons,
        if (override != null) RestReasonCode.sessionOverride,
      ],
      transitionType: RestTransitionType.supersetCycle,
      isUserOverridden: override != null,
    );
  }

  RestRecommendation _withExerciseOverride(
    RestRecommendation recommendation,
    int? seconds,
  ) {
    final override = _validUserSeconds(seconds);
    if (override == null) return recommendation;
    return RestRecommendation(
      recommendedSeconds: recommendation.recommendedSeconds,
      plannedSeconds: override,
      baseSeconds: recommendation.baseSeconds,
      modifierSeconds: recommendation.modifierSeconds,
      source: RestSource.sessionExerciseOverride,
      reasonCodes: [
        ...recommendation.reasonCodes,
        RestReasonCode.sessionOverride,
      ],
      transitionType: recommendation.transitionType,
      isUserOverridden: true,
      nextExerciseId: recommendation.nextExerciseId,
      shouldStartTimer: recommendation.shouldStartTimer,
    );
  }

  int _effectiveBase(
    ExerciseRestProfile? profile,
    RestPrescription? prescription,
  ) => prescription?.validFixedSeconds ?? _baseSeconds(profile);

  int _baseSeconds(ExerciseRestProfile? profile) =>
      profile?.baseRestSeconds ?? ExerciseRestClass.other.baseRestSeconds;

  int _preWorkingRecovery(ExerciseRestProfile? profile) {
    final restClass = profile?.restClass ?? ExerciseRestClass.other;
    return switch (restClass) {
      ExerciseRestClass.smallMuscleIsolation ||
      ExerciseRestClass.isolation ||
      ExerciseRestClass.other => 90,
      ExerciseRestClass.machineCompound => 120,
      ExerciseRestClass.standardCompound => 150,
      ExerciseRestClass.heavyCompound => 180,
      ExerciseRestClass.olympicPower => 240,
    };
  }

  RestReasonCode _classReason(ExerciseRestClass restClass) =>
      switch (restClass) {
        ExerciseRestClass.olympicPower => RestReasonCode.olympicPower,
        ExerciseRestClass.heavyCompound => RestReasonCode.heavyCompound,
        ExerciseRestClass.standardCompound => RestReasonCode.standardCompound,
        ExerciseRestClass.machineCompound => RestReasonCode.machineCompound,
        ExerciseRestClass.isolation => RestReasonCode.isolation,
        ExerciseRestClass.smallMuscleIsolation =>
          RestReasonCode.smallMuscleIsolation,
        ExerciseRestClass.other => RestReasonCode.isolation,
      };

  int _recommendedClamp(int seconds) => seconds.clamp(30, 300);

  int? _validUserSeconds(int? seconds) =>
      seconds != null && seconds >= 15 && seconds <= 600 ? seconds : null;
}
