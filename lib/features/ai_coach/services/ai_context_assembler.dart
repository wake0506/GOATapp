import '../models/ai_memory.dart';
import 'knowledge_retrieval_service.dart';

class AiContextRequest {
  const AiContextRequest({
    required this.taskType,
    required this.memories,
    required this.retrievedKnowledge,
    this.dataEvidence = const {},
    this.currentTaskContext = const {},
  });

  final AiCoachTaskType taskType;
  final List<AiMemoryItem> memories;
  final RetrievedKnowledgeContext retrievedKnowledge;
  final Map<String, dynamic> dataEvidence;
  final Map<String, dynamic> currentTaskContext;
}

class AssembledAiContext {
  const AssembledAiContext({
    required this.taskType,
    required this.payload,
    required this.allowedEvidenceRefs,
    required this.allowedKnowledgeRefs,
  });

  final AiCoachTaskType taskType;
  final Map<String, dynamic> payload;
  final Set<String> allowedEvidenceRefs;
  final Set<String> allowedKnowledgeRefs;
}

class AiContextAssembler {
  const AiContextAssembler();

  AssembledAiContext assemble(AiContextRequest request) {
    final usableMemories = request.memories
        .where(
          (item) =>
              item.isUsableInContext &&
              _memoryCategories(request.taskType).contains(item.category),
        )
        .map(
          (item) => {
            'id': item.id,
            'category': item.category.name,
            'value': item.value,
            'sourceType': item.sourceType.name,
            'sourceRefs': item.sourceRefs.map((ref) => ref.id).toList(),
          },
        )
        .toList();
    final evidence = _minimizeEvidence(request.taskType, request.dataEvidence);
    final taskContext = _minimizeTaskContext(
      request.taskType,
      request.currentTaskContext,
    );
    final evidenceRefs = evidence.keys.toSet();
    final knowledgeRefs = request.retrievedKnowledge.entries
        .map((item) => item.id)
        .toSet();
    return AssembledAiContext(
      taskType: request.taskType,
      allowedEvidenceRefs: evidenceRefs,
      allowedKnowledgeRefs: knowledgeRefs,
      payload: {
        'contractVersion': 1,
        'taskType': request.taskType.name,
        'rules': const {
          'explainOnly': true,
          'neverOverrideDeterministicResults': true,
          'neverApplyWithoutUserConfirmation': true,
          'returnStructuredJson': true,
          'allowedUncertainties': [
            'insufficientEvidence',
            'partialData',
            'missingUserContext',
            'needsConfirmation',
          ],
        },
        'approvedMemory': usableMemories,
        'dataEvidence': evidence,
        'taskContext': taskContext,
        'retrievedKnowledge': request.retrievedKnowledge.entries
            .map((item) => item.toContextJson())
            .toList(),
        'responseSchema': const {
          'answer': 'string',
          'summary': 'string',
          'evidenceRefs': ['allowed data evidence ids only'],
          'knowledgeRefs': ['retrieved kb ids only'],
          'suggestions': ['structured AiSuggestion objects only'],
          'uncertainties': ['allowed uncertainty values only'],
        },
      },
    );
  }

  Map<String, dynamic> _minimizeEvidence(
    AiCoachTaskType task,
    Map<String, dynamic> input,
  ) {
    final allowed = switch (task) {
      AiCoachTaskType.restExplanation => const {
        'rest_recommendation',
        'training_session',
      },
      AiCoachTaskType.progressionExplanation => const {
        'progression_recommendation',
        'training_session',
      },
      AiCoachTaskType.coverageExplanation ||
      AiCoachTaskType.exerciseSelection => const {
        'coverage_result',
        'exercise_recommendation',
        'weekly_review',
      },
      AiCoachTaskType.weightTrend => const {'trend_weight'},
      AiCoachTaskType.nutrition => const {'nutrition_summary', 'trend_weight'},
      AiCoachTaskType.trainingSummary => const {
        'weekly_review',
        'coverage_result',
        'training_session',
      },
      AiCoachTaskType.profile => const {
        'training_history_summary',
        'suggestion_feedback_summary',
      },
    };
    return {
      for (final entry in input.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  Map<String, dynamic> _minimizeTaskContext(
    AiCoachTaskType task,
    Map<String, dynamic> input,
  ) {
    final allowed = switch (task) {
      AiCoachTaskType.restExplanation => const {
        'restRecommendation',
        'exerciseMetadata',
        'currentSet',
      },
      AiCoachTaskType.progressionExplanation => const {
        'progressionRecommendation',
        'exerciseMetadata',
        'recentExerciseSummary',
      },
      AiCoachTaskType.coverageExplanation => const {
        'coverage',
        'exerciseRecommendation',
      },
      AiCoachTaskType.exerciseSelection => const {
        'exerciseRecommendation',
        'coverage',
        'availableEquipment',
      },
      AiCoachTaskType.nutrition => const {
        'nutritionSummary',
        'currentMeal',
        'targets',
        'weightTrend',
        'trainingGoal',
        'nutritionPreference',
      },
      AiCoachTaskType.weightTrend => const {'weightTrend'},
      AiCoachTaskType.trainingSummary => const {
        'weeklyReview',
        'coverage',
        'progressionSummary',
      },
      AiCoachTaskType.profile => const {'profileSummary', 'behaviorSummary'},
    };
    return {
      for (final entry in input.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  Set<AiProfileCategory> _memoryCategories(AiCoachTaskType task) =>
      switch (task) {
        AiCoachTaskType.nutrition => const {
          AiProfileCategory.trainingGoal,
          AiProfileCategory.nutritionPreference,
          AiProfileCategory.coachingStyle,
          AiProfileCategory.constraint,
        },
        AiCoachTaskType.progressionExplanation => const {
          AiProfileCategory.trainingGoal,
          AiProfileCategory.trainingExperience,
          AiProfileCategory.trainingPreference,
          AiProfileCategory.coachingStyle,
          AiProfileCategory.constraint,
        },
        AiCoachTaskType.restExplanation => const {
          AiProfileCategory.trainingPreference,
          AiProfileCategory.trainingHabit,
          AiProfileCategory.coachingStyle,
          AiProfileCategory.constraint,
        },
        AiCoachTaskType.coverageExplanation ||
        AiCoachTaskType.exerciseSelection => const {
          AiProfileCategory.trainingGoal,
          AiProfileCategory.availableEquipment,
          AiProfileCategory.trainingPreference,
          AiProfileCategory.dislikedExercise,
          AiProfileCategory.coachingStyle,
          AiProfileCategory.constraint,
        },
        AiCoachTaskType.trainingSummary => const {
          AiProfileCategory.trainingGoal,
          AiProfileCategory.trainingPreference,
          AiProfileCategory.nutritionPreference,
          AiProfileCategory.coachingStyle,
          AiProfileCategory.constraint,
        },
        AiCoachTaskType.weightTrend => const {
          AiProfileCategory.trainingGoal,
          AiProfileCategory.coachingStyle,
        },
        AiCoachTaskType.profile => AiProfileCategory.values.toSet(),
      };
}
