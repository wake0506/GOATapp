enum TrainingSessionState {
  idle,
  preparing,
  activeSet,
  setCompleted,
  resting,
  readyForNextSet,
  paused,
  finished,
}

enum TrainingSetType { warmup, working, drop, amrap, failure, superset }

enum TrainingExerciseStatus { planned, active, completed, skipped, replaced }

extension TrainingSessionStateCodec on TrainingSessionState {
  String get storageValue => name;

  static TrainingSessionState? fromStorage(Object? value) =>
      _fromName(TrainingSessionState.values, value);
}

extension TrainingSetTypeCodec on TrainingSetType {
  String get storageValue => name;

  static TrainingSetType? fromStorage(Object? value) =>
      _fromName(TrainingSetType.values, value);
}

extension TrainingExerciseStatusCodec on TrainingExerciseStatus {
  String get storageValue => name;

  static TrainingExerciseStatus? fromStorage(Object? value) =>
      _fromName(TrainingExerciseStatus.values, value);
}

T? _fromName<T extends Enum>(Iterable<T> values, Object? value) {
  if (value is! String) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}
