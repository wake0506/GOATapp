import 'json_value.dart';

const int restPolicyVersion = 2;

enum ExerciseRestClass {
  olympicPower,
  heavyCompound,
  standardCompound,
  machineCompound,
  isolation,
  smallMuscleIsolation,
  other,
}

extension ExerciseRestClassCodec on ExerciseRestClass {
  int get baseRestSeconds => switch (this) {
    ExerciseRestClass.olympicPower => 240,
    ExerciseRestClass.heavyCompound => 180,
    ExerciseRestClass.standardCompound => 150,
    ExerciseRestClass.machineCompound => 120,
    ExerciseRestClass.isolation => 90,
    ExerciseRestClass.smallMuscleIsolation => 75,
    ExerciseRestClass.other => 90,
  };

  static ExerciseRestClass? fromStorage(Object? value) {
    if (value is! String) return null;
    for (final candidate in ExerciseRestClass.values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}

class ExerciseRestProfile {
  const ExerciseRestProfile({
    required this.exerciseId,
    required this.restClass,
    this.baseRestSecondsOverride,
  });

  final String exerciseId;
  final ExerciseRestClass restClass;
  final int? baseRestSecondsOverride;

  int get baseRestSeconds =>
      baseRestSecondsOverride ?? restClass.baseRestSeconds;
}

enum RestPrescriptionMode { recommended, fixed }

class RestPrescription {
  const RestPrescription.recommended()
    : mode = RestPrescriptionMode.recommended,
      fixedSeconds = null;

  const RestPrescription.fixed(int seconds)
    : mode = RestPrescriptionMode.fixed,
      fixedSeconds = seconds;

  final RestPrescriptionMode mode;
  final int? fixedSeconds;

  int? get validFixedSeconds {
    final seconds = fixedSeconds;
    if (mode != RestPrescriptionMode.fixed ||
        seconds == null ||
        seconds < 15 ||
        seconds > 600) {
      return null;
    }
    return seconds;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (validFixedSeconds != null) 'fixedSeconds': validFixedSeconds,
  };

  static RestPrescription? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final mode = RestPrescriptionMode.values
        .where((candidate) => candidate.name == json['mode'])
        .firstOrNull;
    if (mode == null) return null;
    if (mode == RestPrescriptionMode.recommended) {
      return const RestPrescription.recommended();
    }
    final seconds = intValue(json['fixedSeconds']);
    if (seconds < 15 || seconds > 600) return null;
    return RestPrescription.fixed(seconds);
  }
}

enum RestSource {
  exerciseProfile,
  templateFixed,
  sessionExerciseOverride,
  supersetOverride,
  legacyFallback,
}

enum RestTransitionType {
  betweenSets,
  warmup,
  exerciseTransition,
  supersetCycle,
  sessionComplete,
}

enum RestReasonCode {
  olympicPower('olympic_power'),
  heavyCompound('heavy_compound'),
  standardCompound('standard_compound'),
  machineCompound('machine_compound'),
  isolation('isolation'),
  smallMuscleIsolation('small_muscle_isolation'),
  warmupLowLoad('warmup_low_load'),
  warmupMediumLoad('warmup_medium_load'),
  warmupHighLoad('warmup_high_load'),
  finalWarmup('final_warmup'),
  rirOne('rir_one'),
  rirZero('rir_zero'),
  reachedFailure('reached_failure'),
  dropSet('drop_set'),
  amrapSet('amrap_set'),
  failureSet('failure_set'),
  exerciseTransition('exercise_transition'),
  sameBodyPartTransition('same_body_part_transition'),
  differentBodyPartTransition('different_body_part_transition'),
  nextHeavyExercise('next_heavy_exercise'),
  supersetTransition('superset_transition'),
  supersetCycleRest('superset_cycle_rest'),
  userFixed('user_fixed'),
  sessionOverride('session_override');

  const RestReasonCode(this.storageValue);

  final String storageValue;

  static RestReasonCode? fromStorage(Object? value) {
    if (value is! String) return null;
    for (final candidate in RestReasonCode.values) {
      if (candidate.storageValue == value) return candidate;
    }
    return null;
  }
}

class RestRecommendation {
  const RestRecommendation({
    required this.recommendedSeconds,
    required this.plannedSeconds,
    required this.baseSeconds,
    required this.modifierSeconds,
    required this.source,
    required this.reasonCodes,
    required this.transitionType,
    this.policyVersion = restPolicyVersion,
    this.isUserOverridden = false,
    this.nextExerciseId,
    this.shouldStartTimer = true,
  });

  const RestRecommendation.sessionComplete()
    : recommendedSeconds = 0,
      plannedSeconds = 0,
      baseSeconds = 0,
      modifierSeconds = 0,
      source = RestSource.exerciseProfile,
      reasonCodes = const [],
      transitionType = RestTransitionType.sessionComplete,
      policyVersion = restPolicyVersion,
      isUserOverridden = false,
      nextExerciseId = null,
      shouldStartTimer = false;

  final int recommendedSeconds;
  final int plannedSeconds;
  final int baseSeconds;
  final int modifierSeconds;
  final RestSource source;
  final List<RestReasonCode> reasonCodes;
  final RestTransitionType transitionType;
  final int policyVersion;
  final bool isUserOverridden;
  final String? nextExerciseId;
  final bool shouldStartTimer;

  Map<String, dynamic> toJson() => {
    'recommendedSeconds': recommendedSeconds,
    'plannedSeconds': plannedSeconds,
    'baseSeconds': baseSeconds,
    'modifierSeconds': modifierSeconds,
    'source': source.name,
    'reasonCodes': reasonCodes
        .map((reason) => reason.storageValue)
        .toList(growable: false),
    'transitionType': transitionType.name,
    'policyVersion': policyVersion,
    'isUserOverridden': isUserOverridden,
    'nextExerciseId': nextExerciseId,
    'shouldStartTimer': shouldStartTimer,
  };

  static RestRecommendation? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final source = RestSource.values
        .where((candidate) => candidate.name == json['source'])
        .firstOrNull;
    final transitionType = RestTransitionType.values
        .where((candidate) => candidate.name == json['transitionType'])
        .firstOrNull;
    if (source == null || transitionType == null) return null;
    return RestRecommendation(
      recommendedSeconds: intValue(json['recommendedSeconds']),
      plannedSeconds: intValue(json['plannedSeconds']),
      baseSeconds: intValue(json['baseSeconds']),
      modifierSeconds: intValue(json['modifierSeconds']),
      source: source,
      reasonCodes: (json['reasonCodes'] as List<dynamic>? ?? const [])
          .map(RestReasonCode.fromStorage)
          .whereType<RestReasonCode>()
          .toList(growable: false),
      transitionType: transitionType,
      policyVersion: intValue(json['policyVersion'], restPolicyVersion),
      isUserOverridden: json['isUserOverridden'] == true,
      nextExerciseId: _nullableString(json['nextExerciseId']),
      shouldStartTimer: json['shouldStartTimer'] != false,
    );
  }
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
