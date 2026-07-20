import 'training_session_state.dart';

enum TrainingSessionEvent {
  startSession,
  confirmSession,
  startSet,
  completeSet,
  startRest,
  skipRest,
  restFinished,
  nextSet,
  pause,
  resume,
  finishSession,
  replaceExercise,
}

class TrainingStateTransition {
  const TrainingStateTransition._({
    required this.from,
    required this.event,
    required this.to,
    required this.isAccepted,
    this.reason,
  });

  const TrainingStateTransition.accepted({
    required TrainingSessionState from,
    required TrainingSessionEvent event,
    required TrainingSessionState to,
  }) : this._(from: from, event: event, to: to, isAccepted: true);

  const TrainingStateTransition.rejected({
    required TrainingSessionState from,
    required TrainingSessionEvent event,
    required String reason,
  }) : this._(
         from: from,
         event: event,
         to: from,
         isAccepted: false,
         reason: reason,
       );

  final TrainingSessionState from;
  final TrainingSessionEvent event;
  final TrainingSessionState to;
  final bool isAccepted;
  final String? reason;
}

class TrainingSessionStateMachine {
  const TrainingSessionStateMachine();

  TrainingStateTransition transition({
    required TrainingSessionState state,
    required TrainingSessionEvent event,
    TrainingSessionState? resumeState,
  }) {
    final nextState = switch ((state, event)) {
      (TrainingSessionState.idle, TrainingSessionEvent.startSession) =>
        TrainingSessionState.preparing,
      (TrainingSessionState.preparing, TrainingSessionEvent.confirmSession) =>
        TrainingSessionState.readyForNextSet,
      (TrainingSessionState.readyForNextSet, TrainingSessionEvent.startSet) =>
        TrainingSessionState.activeSet,
      (TrainingSessionState.activeSet, TrainingSessionEvent.completeSet) =>
        TrainingSessionState.setCompleted,
      (TrainingSessionState.setCompleted, TrainingSessionEvent.startRest) =>
        TrainingSessionState.resting,
      (TrainingSessionState.resting, TrainingSessionEvent.skipRest) ||
      (TrainingSessionState.resting, TrainingSessionEvent.restFinished) ||
      (TrainingSessionState.resting, TrainingSessionEvent.nextSet) ||
      (
        TrainingSessionState.setCompleted,
        TrainingSessionEvent.nextSet,
      ) => TrainingSessionState.readyForNextSet,
      (TrainingSessionState.readyForNextSet, TrainingSessionEvent.nextSet) =>
        TrainingSessionState.readyForNextSet,
      (TrainingSessionState.activeSet, TrainingSessionEvent.replaceExercise) ||
      (
        TrainingSessionState.setCompleted,
        TrainingSessionEvent.replaceExercise,
      ) => TrainingSessionState.readyForNextSet,
      (TrainingSessionState.resting, TrainingSessionEvent.replaceExercise) =>
        TrainingSessionState.resting,
      (TrainingSessionState.preparing, TrainingSessionEvent.replaceExercise) ||
      (
        TrainingSessionState.readyForNextSet,
        TrainingSessionEvent.replaceExercise,
      ) => state,
      (_, TrainingSessionEvent.pause) when _canPause(state) =>
        TrainingSessionState.paused,
      (TrainingSessionState.paused, TrainingSessionEvent.resume)
          when resumeState != null &&
              resumeState != TrainingSessionState.paused =>
        resumeState,
      (_, TrainingSessionEvent.finishSession) when _canFinish(state) =>
        TrainingSessionState.finished,
      _ => null,
    };

    if (nextState == null) {
      return TrainingStateTransition.rejected(
        from: state,
        event: event,
        reason: 'Event ${event.name} is not allowed from ${state.name}.',
      );
    }
    return TrainingStateTransition.accepted(
      from: state,
      event: event,
      to: nextState,
    );
  }

  static bool _canPause(TrainingSessionState state) => switch (state) {
    TrainingSessionState.preparing ||
    TrainingSessionState.activeSet ||
    TrainingSessionState.setCompleted ||
    TrainingSessionState.resting ||
    TrainingSessionState.readyForNextSet => true,
    _ => false,
  };

  static bool _canFinish(TrainingSessionState state) => switch (state) {
    TrainingSessionState.preparing ||
    TrainingSessionState.activeSet ||
    TrainingSessionState.setCompleted ||
    TrainingSessionState.resting ||
    TrainingSessionState.readyForNextSet ||
    TrainingSessionState.paused => true,
    _ => false,
  };
}
