import '../models/ai_coach_response.dart';
import '../models/ai_suggestion.dart';
import 'ai_context_assembler.dart';
import 'knowledge_retrieval_service.dart';

class AiCoachResponseValidator {
  const AiCoachResponseValidator();

  AiCoachResponse validate(
    AiCoachResponse response,
    AssembledAiContext context,
  ) {
    final evidence = response.evidenceRefs
        .where(context.allowedEvidenceRefs.contains)
        .toSet()
        .toList();
    final knowledge = response.knowledgeRefs
        .where(context.allowedKnowledgeRefs.contains)
        .toSet()
        .toList();
    final suggestions = _isExplanationTask(context.taskType)
        ? response.suggestions
              .where((item) => !_overridesDeterministicResult(item))
              .toList()
        : response.suggestions;
    final uncertainties = [...response.uncertainties];
    if (evidence.isEmpty &&
        knowledge.isEmpty &&
        !uncertainties.contains(AiCoachUncertainty.insufficientEvidence)) {
      uncertainties.add(AiCoachUncertainty.insufficientEvidence);
    }
    return response.copyWith(
      evidenceRefs: evidence,
      knowledgeRefs: knowledge,
      suggestions: suggestions,
      uncertainties: uncertainties,
    );
  }

  bool _isExplanationTask(AiCoachTaskType task) =>
      task == AiCoachTaskType.progressionExplanation ||
      task == AiCoachTaskType.restExplanation ||
      task == AiCoachTaskType.coverageExplanation ||
      task == AiCoachTaskType.exerciseSelection ||
      task == AiCoachTaskType.weightTrend;

  bool _overridesDeterministicResult(AiSuggestion suggestion) {
    final type = suggestion.proposedAction?.type;
    return type == AiProposedActionType.updateProgressionTarget ||
        type == AiProposedActionType.updateRestPrescription ||
        type == AiProposedActionType.suggestExercise;
  }
}
