import '../data/goat_knowledge_base_v1.dart';
import '../models/knowledge_entry.dart';

enum AiCoachTaskType {
  profile,
  trainingSummary,
  progressionExplanation,
  restExplanation,
  coverageExplanation,
  exerciseSelection,
  nutrition,
  weightTrend,
}

enum RetrievedKnowledgeQuality { high, medium, low, insufficient }

class KnowledgeRetrievalRequest {
  const KnowledgeRetrievalRequest({
    required this.taskType,
    this.query,
    this.reasonCodes = const [],
    this.structuredContext = const {},
    this.requestedCategory,
    this.limit = 5,
  });

  final AiCoachTaskType taskType;
  final String? query;
  final List<String> reasonCodes;
  final Map<String, dynamic> structuredContext;
  final KnowledgeCategory? requestedCategory;
  final int limit;
}

class RetrievedKnowledgeContext {
  const RetrievedKnowledgeContext({
    required this.entries,
    required this.sourceRefs,
    required this.dataQuality,
  });

  final List<KnowledgeEntry> entries;
  final List<String> sourceRefs;
  final RetrievedKnowledgeQuality dataQuality;
}

class KnowledgeRetrievalService {
  const KnowledgeRetrievalService({this.entries = GoatKnowledgeBaseV1.entries});

  final List<KnowledgeEntry> entries;

  RetrievedKnowledgeContext retrieve(KnowledgeRetrievalRequest request) {
    final approved = entries
        .where((item) => item.reviewStatus == KnowledgeReviewStatus.approved)
        .toList();
    final query = (request.query ?? '').trim().toLowerCase();
    final taskContext = _taskContext(request.taskType);
    final taskCategories = _taskCategories(request.taskType);
    final reasonCodes = request.reasonCodes
        .map((item) => item.toLowerCase())
        .toSet();
    final scored =
        approved
            .map((entry) {
              var score = entry.stablePriority;
              if (request.requestedCategory == entry.category) score += 30;
              if (taskCategories.contains(entry.category)) score += 20;
              if (entry.applicableContexts.contains(taskContext)) score += 15;
              for (final tag in entry.tags) {
                final normalized = tag.toLowerCase();
                if (reasonCodes.contains(normalized)) score += 12;
                if (query.isNotEmpty &&
                    (query.contains(normalized) ||
                        entry.title.toLowerCase().contains(query) ||
                        entry.content.toLowerCase().contains(query))) {
                  score += 5;
                }
              }
              return (entry: entry, score: score);
            })
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) {
            final score = b.score.compareTo(a.score);
            return score != 0 ? score : a.entry.id.compareTo(b.entry.id);
          });
    final selected = scored
        .take(request.limit.clamp(1, 10))
        .map((item) => item.entry)
        .toList();
    return RetrievedKnowledgeContext(
      entries: selected,
      sourceRefs: selected.map((item) => item.id).toList(),
      dataQuality: selected.length >= 3
          ? RetrievedKnowledgeQuality.high
          : selected.isNotEmpty
          ? RetrievedKnowledgeQuality.medium
          : RetrievedKnowledgeQuality.insufficient,
    );
  }

  Set<KnowledgeCategory> _taskCategories(AiCoachTaskType task) =>
      switch (task) {
        AiCoachTaskType.progressionExplanation => const {
          KnowledgeCategory.progression,
          KnowledgeCategory.goatRuleExplanations,
        },
        AiCoachTaskType.restExplanation => const {
          KnowledgeCategory.restAndRecovery,
          KnowledgeCategory.goatRuleExplanations,
        },
        AiCoachTaskType.coverageExplanation => const {
          KnowledgeCategory.trainingCoverage,
          KnowledgeCategory.exerciseSelection,
        },
        AiCoachTaskType.exerciseSelection => const {
          KnowledgeCategory.exerciseSelection,
          KnowledgeCategory.trainingCoverage,
        },
        AiCoachTaskType.nutrition => const {
          KnowledgeCategory.nutritionGeneral,
          KnowledgeCategory.goatRuleExplanations,
        },
        AiCoachTaskType.weightTrend => const {
          KnowledgeCategory.weightTrend,
          KnowledgeCategory.goatRuleExplanations,
        },
        AiCoachTaskType.trainingSummary => const {
          KnowledgeCategory.trainingPrinciples,
          KnowledgeCategory.goatRuleExplanations,
        },
        AiCoachTaskType.profile => const {
          KnowledgeCategory.trainingPrinciples,
          KnowledgeCategory.goatRuleExplanations,
        },
      };

  String _taskContext(AiCoachTaskType task) => switch (task) {
    AiCoachTaskType.progressionExplanation => 'progression_explanation',
    AiCoachTaskType.restExplanation => 'rest_explanation',
    AiCoachTaskType.coverageExplanation => 'coverage_explanation',
    AiCoachTaskType.exerciseSelection => 'exercise_selection',
    AiCoachTaskType.nutrition => 'nutrition',
    AiCoachTaskType.weightTrend => 'weight_trend',
    AiCoachTaskType.trainingSummary => 'training',
    AiCoachTaskType.profile => 'profile',
  };
}
