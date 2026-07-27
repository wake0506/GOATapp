import '../models/ai_suggestion.dart';

class AiSuggestionTransitionService {
  const AiSuggestionTransitionService();

  AiSuggestion transition(
    AiSuggestion suggestion,
    AiSuggestionStatus next, {
    AiProposedAction? modifiedAction,
    String? failureMessage,
  }) {
    final allowed = switch (suggestion.status) {
      AiSuggestionStatus.proposed => const {
        AiSuggestionStatus.accepted,
        AiSuggestionStatus.modified,
        AiSuggestionStatus.rejected,
        AiSuggestionStatus.dismissed,
      },
      AiSuggestionStatus.modified => const {
        AiSuggestionStatus.accepted,
        AiSuggestionStatus.rejected,
        AiSuggestionStatus.dismissed,
      },
      AiSuggestionStatus.accepted || AiSuggestionStatus.applyFailed => const {
        AiSuggestionStatus.applied,
        AiSuggestionStatus.applyFailed,
        AiSuggestionStatus.rejected,
        AiSuggestionStatus.dismissed,
      },
      AiSuggestionStatus.rejected ||
      AiSuggestionStatus.dismissed ||
      AiSuggestionStatus.applied => const <AiSuggestionStatus>{},
    };
    if (!allowed.contains(next)) {
      throw StateError(
        'Illegal suggestion transition: ${suggestion.status.name} -> ${next.name}',
      );
    }
    return suggestion.copyWith(
      proposedAction: modifiedAction,
      status: next,
      failureMessage: failureMessage,
      clearFailure: next != AiSuggestionStatus.applyFailed,
    );
  }
}

typedef AiActionValidator = Future<bool> Function(AiProposedAction action);
typedef AiActionPersister = Future<void> Function(AiProposedAction action);
typedef AiSuggestionTransitionRecorder =
    Future<void> Function(AiSuggestion suggestion);

class AiSuggestionApplicationService {
  const AiSuggestionApplicationService({
    this.transitions = const AiSuggestionTransitionService(),
  });

  final AiSuggestionTransitionService transitions;

  Future<AiSuggestion> apply({
    required AiSuggestion suggestion,
    required bool userConfirmed,
    required AiActionValidator validate,
    required AiActionPersister persist,
    AiProposedAction? modifiedAction,
    AiSuggestionTransitionRecorder? onTransition,
  }) async {
    if (!userConfirmed) return suggestion;
    final action = modifiedAction ?? suggestion.proposedAction;
    final acceptedStatus = modifiedAction == null
        ? AiSuggestionStatus.accepted
        : AiSuggestionStatus.modified;
    var accepted = suggestion.status == AiSuggestionStatus.proposed
        ? transitions.transition(
            suggestion,
            acceptedStatus,
            modifiedAction: modifiedAction,
          )
        : suggestion;
    if (accepted != suggestion) await onTransition?.call(accepted);
    if (accepted.status == AiSuggestionStatus.modified) {
      accepted = transitions.transition(
        accepted,
        AiSuggestionStatus.accepted,
        modifiedAction: modifiedAction,
      );
      await onTransition?.call(accepted);
    }
    if (action == null) return accepted;
    try {
      if (!await validate(action)) {
        final failed = transitions.transition(
          accepted,
          AiSuggestionStatus.applyFailed,
          failureMessage: '建议不再符合当前数据，请重新检查。',
        );
        await onTransition?.call(failed);
        return failed;
      }
      await persist(action);
      final applied = transitions.transition(
        accepted,
        AiSuggestionStatus.applied,
      );
      await onTransition?.call(applied);
      return applied;
    } catch (_) {
      final failed = transitions.transition(
        accepted,
        AiSuggestionStatus.applyFailed,
        failureMessage: '保存失败，原数据未改变。',
      );
      await onTransition?.call(failed);
      return failed;
    }
  }
}
