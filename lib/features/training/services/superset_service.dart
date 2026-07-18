import '../../../models/training.dart';
import '../domain/training_session_state.dart';

class SupersetSetTarget {
  const SupersetSetTarget({required this.exerciseId, required this.setId});

  final String exerciseId;
  final String setId;
}

class SupersetService {
  const SupersetService();

  String pair({
    required TrainingSession session,
    required String firstExerciseId,
    required String secondExerciseId,
    String? groupId,
  }) {
    if (firstExerciseId == secondExerciseId) {
      throw ArgumentError('A superset requires two different exercises.');
    }
    final first = _activeExercise(session, firstExerciseId);
    final second = _activeExercise(session, secondExerciseId);
    if (first == null || second == null) {
      throw StateError('Both superset exercises must be active.');
    }

    clear(session: session, exerciseId: firstExerciseId);
    clear(session: session, exerciseId: secondExerciseId);
    final resolvedGroupId =
        groupId ??
        _stableGroupId(session.id, firstExerciseId, secondExerciseId);
    first.supersetGroupId = resolvedGroupId;
    second.supersetGroupId = resolvedGroupId;
    for (final exercise in [first, second]) {
      for (final set in exercise.sets) {
        if (set.completedAt == null) set.setType = TrainingSetType.superset;
      }
    }
    return resolvedGroupId;
  }

  void clear({required TrainingSession session, required String exerciseId}) {
    final exercise = _activeExercise(session, exerciseId);
    final groupId = exercise?.supersetGroupId;
    if (groupId == null) return;
    for (final member in session.exercises.where(
      (candidate) => candidate.supersetGroupId == groupId,
    )) {
      member.supersetGroupId = null;
      for (final set in member.sets) {
        if (set.completedAt == null &&
            set.resolvedSetType == TrainingSetType.superset) {
          set.setType = TrainingSetType.working;
        }
      }
    }
  }

  List<TrainingExercise> membersFor(
    TrainingSession session,
    String exerciseId,
  ) {
    final groupId = _activeExercise(session, exerciseId)?.supersetGroupId;
    if (groupId == null) return const [];
    final members = session.exercises
        .where(
          (exercise) =>
              exercise.status != TrainingExerciseStatus.replaced &&
              exercise.supersetGroupId == groupId,
        )
        .toList();
    members.sort((a, b) => _order(session, a).compareTo(_order(session, b)));
    return members.length == 2 ? members : const [];
  }

  SupersetSetTarget? partnerAfterCompletedSet({
    required TrainingSession session,
    required String exerciseId,
    required String setId,
  }) {
    final members = membersFor(session, exerciseId);
    if (members.length != 2 || members.first.exerciseId != exerciseId) {
      return null;
    }
    final ordinal = members.first.sets.indexWhere((set) => set.id == setId);
    if (ordinal < 0 || ordinal >= members.last.sets.length) return null;
    final firstSet = members.first.sets[ordinal];
    final partnerSet = members.last.sets[ordinal];
    if (firstSet.resolvedSetType != TrainingSetType.superset ||
        partnerSet.resolvedSetType != TrainingSetType.superset ||
        partnerSet.completedAt != null ||
        members.last.exerciseId == null ||
        partnerSet.id == null) {
      return null;
    }
    return SupersetSetTarget(
      exerciseId: members.last.exerciseId!,
      setId: partnerSet.id!,
    );
  }

  SupersetSetTarget? firstSetAfterRest({
    required TrainingSession session,
    required String exerciseId,
    required String setId,
  }) {
    final members = membersFor(session, exerciseId);
    if (members.length != 2 || members.last.exerciseId != exerciseId) {
      return null;
    }
    final ordinal = members.last.sets.indexWhere((set) => set.id == setId);
    final nextOrdinal = ordinal + 1;
    if (ordinal < 0 || nextOrdinal >= members.first.sets.length) return null;
    final next = members.first.sets[nextOrdinal];
    if (next.completedAt != null ||
        next.resolvedSetType != TrainingSetType.superset ||
        members.first.exerciseId == null ||
        next.id == null) {
      return null;
    }
    return SupersetSetTarget(
      exerciseId: members.first.exerciseId!,
      setId: next.id!,
    );
  }

  TrainingExercise? _activeExercise(
    TrainingSession session,
    String exerciseId,
  ) => session.exercises
      .where(
        (exercise) =>
            exercise.exerciseId == exerciseId &&
            exercise.status != TrainingExerciseStatus.replaced,
      )
      .firstOrNull;

  int _order(TrainingSession session, TrainingExercise exercise) =>
      exercise.orderIndex ?? session.exercises.indexOf(exercise);

  String _stableGroupId(
    String sessionId,
    String firstExerciseId,
    String secondExerciseId,
  ) {
    final ids = [firstExerciseId, secondExerciseId]..sort();
    return 'sg_${_safe(sessionId)}_${_safe(ids[0])}_${_safe(ids[1])}';
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
