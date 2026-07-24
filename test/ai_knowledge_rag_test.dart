import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/data/goat_knowledge_base_v1.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/models/knowledge_entry.dart';
import 'package:goat_app/features/ai_coach/services/ai_context_assembler.dart';
import 'package:goat_app/features/ai_coach/services/knowledge_retrieval_service.dart';

void main() {
  test('knowledge base has stable unique reviewable entries', () {
    final report = GoatKnowledgeBaseV1.validate();

    expect(report.isValid, isTrue);
    expect(report.total, inInclusiveRange(20, 60));
    expect(report.approved, greaterThanOrEqualTo(20));
    expect(report.draft, 1);
    expect(report.deprecated, 1);
    expect(
      GoatKnowledgeBaseV1.entries.map((item) => item.category).toSet(),
      containsAll(KnowledgeCategory.values),
    );
  });

  for (final scenario in <(AiCoachTaskType, Set<KnowledgeCategory>)>[
    (
      AiCoachTaskType.progressionExplanation,
      {KnowledgeCategory.progression, KnowledgeCategory.goatRuleExplanations},
    ),
    (
      AiCoachTaskType.restExplanation,
      {
        KnowledgeCategory.restAndRecovery,
        KnowledgeCategory.goatRuleExplanations,
      },
    ),
    (
      AiCoachTaskType.coverageExplanation,
      {KnowledgeCategory.trainingCoverage, KnowledgeCategory.exerciseSelection},
    ),
    (
      AiCoachTaskType.nutrition,
      {
        KnowledgeCategory.nutritionGeneral,
        KnowledgeCategory.goatRuleExplanations,
      },
    ),
    (
      AiCoachTaskType.weightTrend,
      {KnowledgeCategory.weightTrend, KnowledgeCategory.goatRuleExplanations},
    ),
  ]) {
    test('${scenario.$1.name} retrieves task-aware approved knowledge', () {
      const service = KnowledgeRetrievalService();
      final result = service.retrieve(
        KnowledgeRetrievalRequest(taskType: scenario.$1),
      );

      expect(result.entries, isNotEmpty);
      expect(
        result.entries.every(
          (item) => item.reviewStatus == KnowledgeReviewStatus.approved,
        ),
        isTrue,
      );
      expect(
        result.entries
            .map((item) => item.category)
            .toSet()
            .intersection(scenario.$2),
        isNotEmpty,
      );
    });
  }

  test('retrieval is deterministic for the same input', () {
    const service = KnowledgeRetrievalService();
    const request = KnowledgeRetrievalRequest(
      taskType: AiCoachTaskType.restExplanation,
      query: '卧推 RIR 0 为什么休息 3:30',
      reasonCodes: ['standard_compound', 'rir_zero'],
    );

    final first = service.retrieve(request).sourceRefs;
    final second = service.retrieve(request).sourceRefs;

    expect(second, first);
    expect(first, contains('kb_rest_rir_zero_modifier'));
    expect(first, contains('kb_rest_compound_longer'));
  });

  test('draft and deprecated entries never enter retrieval', () {
    const service = KnowledgeRetrievalService();
    final result = service.retrieve(
      const KnowledgeRetrievalRequest(
        taskType: AiCoachTaskType.restExplanation,
        query: 'draft deprecated',
        limit: 10,
      ),
    );

    expect(result.sourceRefs, isNot(contains('kb_future_recovery_draft')));
    expect(
      result.sourceRefs,
      isNot(contains('kb_legacy_progression_deprecated')),
    );
  });

  group('context minimization', () {
    test('rest context excludes nutrition logs and complete history', () {
      const retrieval = KnowledgeRetrievalService();
      final knowledge = retrieval.retrieve(
        const KnowledgeRetrievalRequest(
          taskType: AiCoachTaskType.restExplanation,
        ),
      );
      final context = const AiContextAssembler().assemble(
        AiContextRequest(
          taskType: AiCoachTaskType.restExplanation,
          memories: [_activeMemory()],
          retrievedKnowledge: knowledge,
          dataEvidence: const {
            'rest_recommendation': {'planned': 210},
            'nutrition_summary': {'kcal': 2000},
          },
          currentTaskContext: const {
            'restRecommendation': {'planned': 210},
            'currentSet': {'rir': 0},
            'nutritionLogs': ['full diet history'],
            'setHistory': ['all training sets'],
          },
        ),
      );

      final payload = context.payload.toString();
      expect(payload, contains('restRecommendation'));
      expect(payload, isNot(contains('nutritionLogs')));
      expect(payload, isNot(contains('full diet history')));
      expect(payload, isNot(contains('setHistory')));
    });

    test('nutrition context excludes set-by-set training history', () {
      const retrieval = KnowledgeRetrievalService();
      final knowledge = retrieval.retrieve(
        const KnowledgeRetrievalRequest(taskType: AiCoachTaskType.nutrition),
      );
      final context = const AiContextAssembler().assemble(
        AiContextRequest(
          taskType: AiCoachTaskType.nutrition,
          memories: const [],
          retrievedKnowledge: knowledge,
          dataEvidence: const {
            'nutrition_summary': {'kcal': 1500},
            'training_session': {'sets': 30},
          },
          currentTaskContext: const {
            'nutritionSummary': {'kcal': 1500},
            'setHistory': ['all sets'],
          },
        ),
      );

      final payload = context.payload.toString();
      expect(payload, contains('nutritionSummary'));
      expect(payload, isNot(contains('setHistory')));
      expect(payload, isNot(contains('training_session')));
    });

    test('pending and suppressed memories never enter AI context', () {
      const retrieval = KnowledgeRetrievalService();
      final knowledge = retrieval.retrieve(
        const KnowledgeRetrievalRequest(taskType: AiCoachTaskType.profile),
      );
      final context = const AiContextAssembler().assemble(
        AiContextRequest(
          taskType: AiCoachTaskType.profile,
          memories: [
            _activeMemory(),
            _memoryWithStatus(
              'pending',
              AiMemoryStatus.pendingConfirmation,
              source: AiMemorySourceType.aiInferred,
            ),
            _memoryWithStatus('rejected', AiMemoryStatus.rejected),
          ],
          retrievedKnowledge: knowledge,
        ),
      );

      final payload = context.payload.toString();
      expect(payload, contains('active preference'));
      expect(payload, isNot(contains('pending')));
      expect(payload, isNot(contains('rejected')));
    });
  });
}

AiMemoryItem _activeMemory() =>
    _memoryWithStatus('active preference', AiMemoryStatus.active);

AiMemoryItem _memoryWithStatus(
  String value,
  AiMemoryStatus status, {
  AiMemorySourceType source = AiMemorySourceType.userProvided,
}) => AiMemoryItem(
  id: value,
  category: AiProfileCategory.trainingPreference,
  value: value,
  sourceType: source,
  status: status,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  userConfirmed: source != AiMemorySourceType.aiInferred,
);
