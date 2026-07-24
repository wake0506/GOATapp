import '../models/ai_coach_response.dart';
import '../models/ai_memory.dart';
import 'ai_coach_response_validator.dart';
import 'ai_context_assembler.dart';
import 'knowledge_retrieval_service.dart';

abstract interface class StructuredAiCoachGateway {
  Future<Object?> generate(Map<String, dynamic> context);
}

class AiCoachExplanationRequest {
  const AiCoachExplanationRequest({
    required this.taskType,
    required this.query,
    required this.memories,
    this.reasonCodes = const [],
    this.dataEvidence = const {},
    this.currentTaskContext = const {},
  });

  final AiCoachTaskType taskType;
  final String query;
  final List<AiMemoryItem> memories;
  final List<String> reasonCodes;
  final Map<String, dynamic> dataEvidence;
  final Map<String, dynamic> currentTaskContext;
}

class AiCoachExplanationService {
  const AiCoachExplanationService({
    required this.gateway,
    this.retrieval = const KnowledgeRetrievalService(),
    this.assembler = const AiContextAssembler(),
    this.parser = const AiCoachResponseParser(),
    this.validator = const AiCoachResponseValidator(),
  });

  final StructuredAiCoachGateway gateway;
  final KnowledgeRetrievalService retrieval;
  final AiContextAssembler assembler;
  final AiCoachResponseParser parser;
  final AiCoachResponseValidator validator;

  Future<AiCoachResponse> explain(AiCoachExplanationRequest request) async {
    final retrieved = retrieval.retrieve(
      KnowledgeRetrievalRequest(
        taskType: request.taskType,
        query: request.query,
        reasonCodes: request.reasonCodes,
        structuredContext: request.currentTaskContext,
      ),
    );
    final context = assembler.assemble(
      AiContextRequest(
        taskType: request.taskType,
        memories: request.memories,
        retrievedKnowledge: retrieved,
        dataEvidence: request.dataEvidence,
        currentTaskContext: request.currentTaskContext,
      ),
    );
    try {
      final response = parser.parse(await gateway.generate(context.payload));
      return validator.validate(response, context);
    } catch (_) {
      return _fallback(request, context);
    }
  }

  AiCoachResponse _fallback(
    AiCoachExplanationRequest request,
    AssembledAiContext context,
  ) {
    final knowledgeRefs = context.allowedKnowledgeRefs.take(2).toList();
    final evidenceRefs = context.allowedEvidenceRefs.take(2).toList();
    final answer = switch (request.taskType) {
      AiCoachTaskType.restExplanation =>
        '当前休息时间由 GOAT Rest Prescription V2 根据动作类型和本组状态计算。AI 暂时不可用，但计时与推荐不受影响。',
      AiCoachTaskType.progressionExplanation =>
        '当前递进结论由 GOAT 的确定性规则根据目标完成度和训练历史计算。AI 暂时不可用，原结论保持不变。',
      AiCoachTaskType.coverageExplanation ||
      AiCoachTaskType.exerciseSelection =>
        '当前覆盖与动作候选来自 GOAT 的训练目录和覆盖引擎。AI 暂时不可用，不影响现有推荐。',
      AiCoachTaskType.weightTrend => '体重趋势继续使用七日移动平均计算。AI 暂时不可用，不影响趋势结果。',
      AiCoachTaskType.nutrition => 'AI 说明暂时不可用，你仍可正常记录饮食并查看确定性的目标与汇总。',
      AiCoachTaskType.trainingSummary ||
      AiCoachTaskType.profile => 'AI 说明暂时不可用，已有训练记录、画像和确定性统计仍可正常使用。',
    };
    return AiCoachResponse(
      answer: answer,
      summary: 'AI 暂时不可用，确定性功能保持正常。',
      evidenceRefs: evidenceRefs,
      knowledgeRefs: knowledgeRefs,
      uncertainties: const [AiCoachUncertainty.insufficientEvidence],
      usedFallback: true,
    );
  }
}
