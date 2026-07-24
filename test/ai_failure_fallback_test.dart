import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_coach_response.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_explanation_service.dart';
import 'package:goat_app/features/ai_coach/services/knowledge_retrieval_service.dart';

void main() {
  test(
    'AI unavailable keeps rest engine result and returns safe fallback',
    () async {
      const service = AiCoachExplanationService(gateway: _FailingGateway());
      final response = await service.explain(
        const AiCoachExplanationRequest(
          taskType: AiCoachTaskType.restExplanation,
          query: '为什么卧推休息 3:30？',
          memories: [],
          reasonCodes: ['standard_compound', 'rir_zero'],
          dataEvidence: {
            'rest_recommendation': {
              'baseSeconds': 150,
              'modifierSeconds': 60,
              'plannedSeconds': 210,
            },
          },
          currentTaskContext: {
            'restRecommendation': {'plannedSeconds': 210},
            'currentSet': {'rir': 0},
          },
        ),
      );

      expect(response.usedFallback, isTrue);
      expect(response.answer, contains('Rest Prescription V2'));
      expect(
        response.uncertainties,
        contains(AiCoachUncertainty.insufficientEvidence),
      );
      expect(response.suggestions, isEmpty);
    },
  );

  test('AI unavailable keeps progression deterministic result', () async {
    const service = AiCoachExplanationService(gateway: _FailingGateway());
    final response = await service.explain(
      const AiCoachExplanationRequest(
        taskType: AiCoachTaskType.progressionExplanation,
        query: '为什么不加重量？',
        memories: [],
        reasonCodes: ['target_incomplete'],
        dataEvidence: {
          'progression_recommendation': {
            'type': 'keep',
            'reason': 'target_incomplete',
          },
        },
      ),
    );

    expect(response.usedFallback, isTrue);
    expect(response.answer, contains('确定性规则'));
    expect(response.answer, contains('原结论保持不变'));
  });
}

class _FailingGateway implements StructuredAiCoachGateway {
  const _FailingGateway();

  @override
  Future<Object?> generate(Map<String, dynamic> context) =>
      Future.error(StateError('offline'));
}
