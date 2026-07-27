import 'ai_coach_response.dart';
import 'ai_suggestion.dart';
import 'knowledge_entry.dart';

enum AiCoachScenarioType {
  nutrition,
  progression,
  rest,
  coverage,
  weeklyReview,
}

class AiCoachEvidenceItem {
  const AiCoachEvidenceItem({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}

class AiCoachScenarioExplanation {
  const AiCoachScenarioExplanation({
    required this.type,
    required this.title,
    required this.headline,
    required this.explanation,
    required this.evidence,
    required this.knowledge,
    this.followUps = const [],
    this.suggestions = const [],
    this.uncertainties = const [],
    this.deterministicAction,
    this.recommendedSeconds,
    this.recommendedExerciseId,
    this.usedFallback = false,
  });

  final AiCoachScenarioType type;
  final String title;
  final String headline;
  final String explanation;
  final List<AiCoachEvidenceItem> evidence;
  final List<KnowledgeEntry> knowledge;
  final List<String> followUps;
  final List<AiSuggestion> suggestions;
  final List<AiCoachUncertainty> uncertainties;
  final String? deterministicAction;
  final int? recommendedSeconds;
  final String? recommendedExerciseId;
  final bool usedFallback;

  bool get partialData =>
      uncertainties.contains(AiCoachUncertainty.partialData);

  bool get insufficientEvidence =>
      uncertainties.contains(AiCoachUncertainty.insufficientEvidence);
}
