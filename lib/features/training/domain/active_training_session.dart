import '../../../models/json_value.dart';
import '../../../models/training.dart';
import 'training_session_state.dart';

class RestState {
  RestState({
    required this.setId,
    required this.restStartedAt,
    required this.restDurationSeconds,
    DateTime? restExpectedEndAt,
  }) : restExpectedEndAt =
           restExpectedEndAt ??
           restStartedAt.add(Duration(seconds: restDurationSeconds));

  final String setId;
  final DateTime restStartedAt;
  final int restDurationSeconds;
  final DateTime restExpectedEndAt;

  RestState copyWith({
    DateTime? restStartedAt,
    int? restDurationSeconds,
    DateTime? restExpectedEndAt,
  }) => RestState(
    setId: setId,
    restStartedAt: restStartedAt ?? this.restStartedAt,
    restDurationSeconds: restDurationSeconds ?? this.restDurationSeconds,
    restExpectedEndAt: restExpectedEndAt ?? this.restExpectedEndAt,
  );

  Duration remainingAt(DateTime now) {
    final remaining = restExpectedEndAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isFinishedAt(DateTime now) => !restExpectedEndAt.isAfter(now);

  Map<String, dynamic> toJson() => {
    'setId': setId,
    'restStartedAt': restStartedAt.toUtc().toIso8601String(),
    'restDurationSeconds': restDurationSeconds,
    'restExpectedEndAt': restExpectedEndAt.toUtc().toIso8601String(),
  };

  factory RestState.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.tryParse(stringValue(json['restStartedAt']));
    final expectedEndAt = DateTime.tryParse(
      stringValue(json['restExpectedEndAt']),
    );
    final duration = intValue(json['restDurationSeconds']);
    if (startedAt == null || duration < 0) {
      throw const FormatException('Invalid persisted rest state.');
    }
    return RestState(
      setId: stringValue(json['setId']),
      restStartedAt: startedAt,
      restDurationSeconds: duration,
      restExpectedEndAt: expectedEndAt,
    );
  }
}

class ActiveTrainingSession {
  const ActiveTrainingSession({
    required this.id,
    required this.draft,
    required this.state,
    required this.startedAt,
    required this.updatedAt,
    this.currentExerciseId,
    this.currentSetId,
    this.rest,
    this.pausedAt,
    this.resumeState,
  });

  final String id;
  final TrainingSession draft;
  final TrainingSessionState state;
  final String? currentExerciseId;
  final String? currentSetId;
  final RestState? rest;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final TrainingSessionState? resumeState;
  final DateTime updatedAt;

  ActiveTrainingSession copyWith({
    TrainingSession? draft,
    TrainingSessionState? state,
    String? currentExerciseId,
    String? currentSetId,
    RestState? rest,
    DateTime? pausedAt,
    TrainingSessionState? resumeState,
    DateTime? updatedAt,
    bool clearCurrentExerciseId = false,
    bool clearCurrentSetId = false,
    bool clearRest = false,
    bool clearPausedAt = false,
    bool clearResumeState = false,
  }) => ActiveTrainingSession(
    id: id,
    draft: draft ?? this.draft,
    state: state ?? this.state,
    currentExerciseId: clearCurrentExerciseId
        ? null
        : currentExerciseId ?? this.currentExerciseId,
    currentSetId: clearCurrentSetId ? null : currentSetId ?? this.currentSetId,
    rest: clearRest ? null : rest ?? this.rest,
    startedAt: startedAt,
    pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
    resumeState: clearResumeState ? null : resumeState ?? this.resumeState,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  ActiveTrainingSession recoverAt(DateTime now) {
    if (state == TrainingSessionState.resting &&
        rest?.isFinishedAt(now) == true) {
      return copyWith(
        state: TrainingSessionState.readyForNextSet,
        clearRest: true,
        updatedAt: now,
      );
    }
    if (state == TrainingSessionState.paused &&
        resumeState == TrainingSessionState.resting &&
        rest?.isFinishedAt(now) == true) {
      return copyWith(
        state: TrainingSessionState.readyForNextSet,
        clearRest: true,
        clearPausedAt: true,
        clearResumeState: true,
        updatedAt: now,
      );
    }
    return this;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'draft': draft.toJson(),
    'state': state.storageValue,
    'currentExerciseId': currentExerciseId,
    'currentSetId': currentSetId,
    'rest': rest?.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'pausedAt': pausedAt?.toUtc().toIso8601String(),
    'resumeState': resumeState?.storageValue,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ActiveTrainingSession.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'];
    final startedAt = DateTime.tryParse(stringValue(json['startedAt']));
    final updatedAt = DateTime.tryParse(stringValue(json['updatedAt']));
    final state = TrainingSessionStateCodec.fromStorage(json['state']);
    if (draft is! Map ||
        startedAt == null ||
        updatedAt == null ||
        state == null) {
      throw const FormatException('Invalid persisted active training session.');
    }
    final rest = json['rest'];
    return ActiveTrainingSession(
      id: stringValue(json['id']),
      draft: TrainingSession.fromJson(Map<String, dynamic>.from(draft)),
      state: state,
      currentExerciseId: _nullableString(json['currentExerciseId']),
      currentSetId: _nullableString(json['currentSetId']),
      rest: rest is Map
          ? RestState.fromJson(Map<String, dynamic>.from(rest))
          : null,
      startedAt: startedAt,
      pausedAt: DateTime.tryParse(stringValue(json['pausedAt'])),
      resumeState: TrainingSessionStateCodec.fromStorage(json['resumeState']),
      updatedAt: updatedAt,
    );
  }
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}
