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
      AiSuggestionStatus.accepted ||
      AiSuggestionStatus.modified ||
      AiSuggestionStatus.applyFailed => const {
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
    if (action == null) return accepted;
    try {
      if (!await validate(action)) {
        return transitions.transition(
          accepted,
          AiSuggestionStatus.applyFailed,
          failureMessage: '建议不再符合当前数据，请重新检查。',
        );
      }
      await persist(action);
      return transitions.transition(accepted, AiSuggestionStatus.applied);
    } catch (_) {
      return transitions.transition(
        accepted,
        AiSuggestionStatus.applyFailed,
        failureMessage: '保存失败，原数据未改变。',
      );
    }
  }
}
