import '../../../models/progression_target.dart';
import '../../../models/rest_prescription.dart';
import '../../analytics/models/progression_recommendation.dart';
import '../../analytics/models/weight_trend.dart';
import '../../analytics/models/weekly_review.dart';
import '../../training/models/exercise_metadata.dart';
import '../../training/models/exercise_recommendation.dart';
import '../../training/models/training_coverage.dart';
import '../models/ai_coach_response.dart';
import '../models/ai_memory.dart';
import '../models/ai_scenario_explanation.dart';
import '../models/ai_suggestion.dart';
import '../models/knowledge_entry.dart';
import 'ai_coach_response_validator.dart';
import 'ai_context_assembler.dart';
import 'knowledge_retrieval_service.dart';

class AiCoachScenarioService {
  const AiCoachScenarioService({
    this.retrieval = const KnowledgeRetrievalService(),
    this.assembler = const AiContextAssembler(),
    this.validator = const AiCoachResponseValidator(),
  });

  final KnowledgeRetrievalService retrieval;
  final AiContextAssembler assembler;
  final AiCoachResponseValidator validator;

  AiCoachScenarioExplanation nutrition({
    required WeeklyNutritionReview review,
    required double? calorieTarget,
    required List<AiMemoryItem> memories,
    String? trainingGoal,
    String? nutritionPreference,
  }) {
    final partial = review.recordedDays > 0 && review.recordedDays < 7;
    final insufficient = review.recordedDays < 3;
    final headline = switch (review.recordedDays) {
      0 => '本周还没有饮食记录',
      7 => '本周记录 7 / 7 天',
      _ => '本周记录 ${review.recordedDays} / 7 天',
    };
    final baseExplanation = review.recordedDays == 0
        ? '先记录几天饮食后，GOAT 才能基于真实数据说明营养趋势。'
        : partial
        ? '当前数据不完整，以下观察只基于已记录日期，不用于判断完整周热量趋势。'
        : '记录覆盖完整一周，可以结合平均营养与趋势体重查看本周情况。';
    final explanation = _applyStyle(
      baseExplanation,
      memories,
      dataLead: headline,
    );
    final taskContext = <String, dynamic>{
      'nutritionSummary': {
        'recordedDays': review.recordedDays,
        'averageCalories': review.averageCalories,
        'averageProtein': review.averageProtein,
        'averageCarbs': review.averageCarbs,
        'averageFat': review.averageFat,
        'partialData': partial,
      },
      'targets': {'calorieGoal': calorieTarget},
      'weightTrend': review.weightTrend.toJson(),
      'trainingGoal': ?trainingGoal,
      'nutritionPreference': ?nutritionPreference,
    };
    final context = _context(
      task: AiCoachTaskType.nutrition,
      query: '营养记录完整度与本周饮食说明',
      reasonCodes: [
        if (partial) 'partial_nutrition_logging',
        if (insufficient) 'insufficient_data',
      ],
      memories: memories,
      evidence: {
        'nutrition_summary': taskContext['nutritionSummary'],
        'trend_weight': review.weightTrend.toJson(),
      },
      taskContext: taskContext,
    );
    final validated = _validate(
      context,
      answer: explanation,
      summary: headline,
      uncertainties: [
        if (partial) AiCoachUncertainty.partialData,
        if (insufficient) AiCoachUncertainty.insufficientEvidence,
      ],
    );
    return AiCoachScenarioExplanation(
      type: AiCoachScenarioType.nutrition,
      title: 'GOAT 营养建议',
      headline: headline,
      explanation: explanation,
      evidence: [
        AiCoachEvidenceItem(
          id: 'nutrition_summary',
          label: '你的数据',
          value: _nutritionEvidence(review),
        ),
        AiCoachEvidenceItem(
          id: 'trend_weight',
          label: '趋势体重',
          value: _trendEvidence(review),
        ),
      ],
      knowledge: _validatedKnowledge(context, validated),
      followUps: const ['数据够完整吗？', '这周应该关注什么？'],
      uncertainties: validated.uncertainties,
    );
  }

  AiCoachScenarioExplanation progression({
    required ProgressionRecommendation recommendation,
    required String exerciseName,
    required List<AiMemoryItem> memories,
    ProgressionTarget? target,
    double? referenceWeightKg,
  }) {
    final action = recommendation.type.name;
    final headline = switch (recommendation.type) {
      ProgressionRecommendationType.increaseWeight => '规则引擎建议增加重量',
      ProgressionRecommendationType.increaseReps => '规则引擎建议优先增加次数',
      ProgressionRecommendationType.keep => '规则引擎建议保持当前重量',
      ProgressionRecommendationType.decreaseWeight => '规则引擎建议降低重量',
      ProgressionRecommendationType.insufficientData => '当前数据不足，暂不递进',
    };
    final explanation = _applyStyle(
      _progressionExplanation(recommendation),
      memories,
      dataLead: '动作 $action · 数据质量 ${recommendation.dataQuality.name}',
    );
    final context = _context(
      task: AiCoachTaskType.progressionExplanation,
      query:
          '$exerciseName $action ${recommendation.reasons.map((e) => e.code).join(' ')}',
      reasonCodes: recommendation.reasons.map((e) => e.code).toList(),
      memories: memories,
      evidence: {
        'progression_recommendation': {
          'action': action,
          'reasonCodes': recommendation.reasons.map((e) => e.code).toList(),
          'dataQuality': recommendation.dataQuality.name,
          'suggestedWeightKg': recommendation.suggestedWeightKg,
        },
        'training_session': {
          'basedOnSessionId': recommendation.basedOnSessionId,
          'basedOnSessionDate': recommendation.basedOnSessionDate
              ?.toIso8601String(),
        },
      },
      taskContext: {
        'progressionRecommendation': {
          'action': action,
          'reasonCodes': recommendation.reasons.map((e) => e.code).toList(),
          'dataQuality': recommendation.dataQuality.name,
        },
        'exerciseMetadata': {'name': exerciseName},
        'recentExerciseSummary': {
          'referenceWeightKg': referenceWeightKg,
          if (target != null)
            'target': {
              'sets': target.targetSets,
              'repMin': target.targetRepMin,
              'repMax': target.targetRepMax,
            },
        },
      },
    );
    final validated = _validate(
      context,
      answer: explanation,
      summary: headline,
      uncertainties:
          recommendation.dataQuality == ProgressionDataQuality.insufficient
          ? const [AiCoachUncertainty.insufficientEvidence]
          : const [],
    );
    return AiCoachScenarioExplanation(
      type: AiCoachScenarioType.progression,
      title: 'GOAT 递进解释',
      headline: headline,
      explanation: explanation,
      evidence: [
        AiCoachEvidenceItem(
          id: 'progression_recommendation',
          label: '确定性结果',
          value:
              '动作 $action · ${recommendation.reasons.map((e) => e.code).join('、')}',
        ),
        AiCoachEvidenceItem(
          id: 'training_session',
          label: '可靠历史',
          value: recommendation.basedOnSessionDate == null
              ? '同动作历史有限'
              : '基于 ${_date(recommendation.basedOnSessionDate!)} 的同动作表现',
        ),
      ],
      knowledge: _validatedKnowledge(context, validated),
      followUps: const ['为什么不加重量？', '这次应该关注什么？', '数据够可靠吗？'],
      uncertainties: validated.uncertainties,
      deterministicAction: action,
    );
  }

  AiCoachScenarioExplanation rest({
    required RestRecommendation recommendation,
    required String exerciseName,
    required List<AiMemoryItem> memories,
    String? setType,
    int? rir,
    bool reachedFailure = false,
  }) {
    final context = _context(
      task: AiCoachTaskType.restExplanation,
      query:
          '$exerciseName ${recommendation.reasonCodes.map((e) => e.storageValue).join(' ')}',
      reasonCodes: recommendation.reasonCodes
          .map((e) => e.storageValue)
          .toList(),
      memories: memories,
      evidence: {
        'rest_recommendation': recommendation.toJson(),
        'training_session': {
          'exerciseName': exerciseName,
          'setType': setType,
          'rir': rir,
          'reachedFailure': reachedFailure,
        },
      },
      taskContext: {
        'restRecommendation': recommendation.toJson(),
        'exerciseMetadata': {'name': exerciseName},
        'currentSet': {
          'setType': setType,
          'rir': rir,
          'reachedFailure': reachedFailure,
        },
      },
    );
    final explanation = _applyStyle(
      _restExplanation(
        recommendation,
        exerciseName: exerciseName,
        rir: rir,
        reachedFailure: reachedFailure,
      ),
      memories,
      dataLead:
          '基础 ${recommendation.baseSeconds} 秒 · 修正 ${_signed(recommendation.modifierSeconds)} 秒',
    );
    final validated = _validate(
      context,
      answer: explanation,
      summary: '推荐 ${_duration(recommendation.recommendedSeconds)}',
    );
    return AiCoachScenarioExplanation(
      type: AiCoachScenarioType.rest,
      title: 'GOAT 休息解释',
      headline: '推荐 ${_duration(recommendation.recommendedSeconds)}',
      explanation: explanation,
      evidence: [
        AiCoachEvidenceItem(
          id: 'rest_recommendation',
          label: '休息规则',
          value:
              '基础 ${recommendation.baseSeconds} 秒 · 修正 ${_signed(recommendation.modifierSeconds)} 秒 · 推荐 ${recommendation.recommendedSeconds} 秒',
        ),
        AiCoachEvidenceItem(
          id: 'training_session',
          label: '本组状态',
          value:
              '${setType ?? '工作组'}${rir == null ? '' : ' · RIR $rir'}${reachedFailure ? ' · 达到力竭' : ''}',
        ),
      ],
      knowledge: _validatedKnowledge(context, validated),
      followUps: const ['为什么需要这么久？', '固定休息和推荐有什么区别？', '+30 秒会改训练方案吗？'],
      uncertainties: validated.uncertainties,
      deterministicAction: recommendation.source.name,
      recommendedSeconds: recommendation.recommendedSeconds,
    );
  }

  AiCoachScenarioExplanation coverage({
    required TrainingCoverageResult coverage,
    required List<ExerciseRecommendationResult> candidates,
    required List<AiMemoryItem> memories,
    MuscleRegion? selectedRegion,
  }) {
    final candidate = candidates.firstOrNull;
    final region = selectedRegion == null
        ? null
        : coverage.region(selectedRegion);
    final context = _context(
      task: AiCoachTaskType.coverageExplanation,
      query:
          '${selectedRegion?.name ?? ''} ${candidate?.movementPattern.name ?? ''} coverage',
      reasonCodes:
          candidate?.reasonCodes.map((e) => e.name).toList() ?? const [],
      memories: memories,
      evidence: {
        'coverage_result': {
          'selectedRegion': selectedRegion?.name,
          'regionLevel': region?.level.name,
          'movementPatterns': coverage.movementPatternCoverage
              .map(
                (e) => {
                  'pattern': e.pattern.name,
                  'level': e.level.name,
                  'effectiveSets': e.effectiveSetCount,
                },
              )
              .toList(),
        },
        'exercise_recommendation': candidate == null
            ? null
            : {
                'exerciseId': candidate.exercise.id,
                'exerciseName': candidate.exercise.name,
                'movementPattern': candidate.movementPattern.name,
                'reasonCodes': candidate.reasonCodes
                    .map((e) => e.name)
                    .toList(),
              },
      },
      taskContext: {
        'coverage': {
          'selectedRegion': selectedRegion?.name,
          'regionLevel': region?.level.name,
        },
        'exerciseRecommendation': candidate == null
            ? null
            : {
                'exerciseId': candidate.exercise.id,
                'exerciseName': candidate.exercise.name,
                'movementPattern': candidate.movementPattern.name,
              },
      },
    );
    final headline = candidate == null
        ? '当前没有目录内的互补动作候选'
        : '下一步可考虑 ${candidate.exercise.name}';
    final baseExplanation = candidate == null
        ? 'GOAT 只解释覆盖引擎与动作目录已经给出的结果，不会临时发明动作。'
        : _coverageExplanation(coverage, candidate, selectedRegion);
    final explanation = _applyStyle(
      baseExplanation,
      memories,
      dataLead: candidate == null
          ? '候选 0'
          : '候选 ${candidate.exercise.name} · ${candidate.movementPattern.name}',
    );
    final validated = _validate(
      context,
      answer: explanation,
      summary: headline,
      uncertainties: candidate == null
          ? const [AiCoachUncertainty.insufficientEvidence]
          : const [],
    );
    return AiCoachScenarioExplanation(
      type: AiCoachScenarioType.coverage,
      title: 'GOAT 覆盖解释',
      headline: headline,
      explanation: explanation,
      evidence: [
        AiCoachEvidenceItem(
          id: 'coverage_result',
          label: '训练覆盖',
          value: selectedRegion == null
              ? '当前窗口 ${coverage.completedEffectiveSets} 个有效组'
              : '${muscleRegionLabel(selectedRegion)}：${coverageLevelLabel(region!.level)}',
        ),
        if (candidate != null)
          AiCoachEvidenceItem(
            id: 'exercise_recommendation',
            label: '动作候选',
            value:
                '${candidate.exercise.name} · ${movementPatternLabel(candidate.movementPattern)}',
          ),
      ],
      knowledge: _validatedKnowledge(context, validated),
      followUps: const ['为什么推荐这个动作？', '我是不是做了太多同类动作？', '这个动作主要补哪里？'],
      uncertainties: validated.uncertainties,
      recommendedExerciseId: candidate?.exercise.id,
    );
  }

  AiCoachScenarioExplanation weekly({
    required WeeklyTrainingReview training,
    required WeeklyNutritionReview nutrition,
    required TrainingCoverageResult? coverage,
    required List<AiMemoryItem> memories,
    String? trainingGoal,
    List<AiSuggestion> suggestions = const [],
  }) {
    final partial = nutrition.recordedDays > 0 && nutrition.recordedDays < 7;
    final insufficient =
        training.sessionCount == 0 && nutrition.recordedDays == 0;
    final observations = <String>[
      if (training.sessionCount > 0)
        '本周完成 ${training.sessionCount} 次训练，共 ${training.effectiveSets} 个有效组。',
      if (nutrition.recordedDays > 0)
        '饮食记录 ${nutrition.recordedDays} / 7 天${partial ? '，营养观察仅基于已记录日期' : ''}。',
      if (nutrition.weightTrend.sevenDayAverageKg != null)
        '趋势体重 ${nutrition.weightTrend.sevenDayAverageKg!.toStringAsFixed(2)} kg。',
      if (training.previousSessionCount != null)
        '上一周期完成 ${training.previousSessionCount} 次训练，本周为 ${training.sessionCount} 次。',
      if (nutrition.previousAverageCalories != null &&
          nutrition.averageCalories != null)
        '上一周期已记录日均 ${nutrition.previousAverageCalories!.round()} kcal，本周已记录日均 ${nutrition.averageCalories!.round()} kcal。',
    ];
    if (observations.isEmpty) {
      observations.add('本周记录还不足，GOAT 暂不生成确定性判断。');
    }
    final context = _context(
      task: AiCoachTaskType.trainingSummary,
      query: '本周训练 营养 体重 覆盖',
      reasonCodes: [
        ...training.reasons.map((e) => e.name),
        ...nutrition.reasons.map((e) => e.name),
      ],
      memories: memories,
      evidence: {
        'weekly_review': {
          'trainingDays': training.trainingDays,
          'sessionCount': training.sessionCount,
          'effectiveSets': training.effectiveSets,
          'recordedNutritionDays': nutrition.recordedDays,
          'nutritionAverages': {
            'calories': nutrition.averageCalories,
            'protein': nutrition.averageProtein,
            'carbs': nutrition.averageCarbs,
            'fat': nutrition.averageFat,
          },
          'weightTrend': nutrition.weightTrend.toJson(),
          'trainingGoal': trainingGoal,
          'previousSessionCount': training.previousSessionCount,
          'previousEffectiveSets': training.previousEffectiveSets,
          'previousAverageCalories': nutrition.previousAverageCalories,
        },
        'coverage_result': coverage == null
            ? null
            : {
                'effectiveSets': coverage.completedEffectiveSets,
                'dataQuality': coverage.dataQuality.name,
              },
      },
      taskContext: {
        'weeklyReview': {
          'trainingDays': training.trainingDays,
          'sessionCount': training.sessionCount,
          'effectiveSets': training.effectiveSets,
          'recordedNutritionDays': nutrition.recordedDays,
          'weightTrend': nutrition.weightTrend.toJson(),
        },
        'coverage': coverage == null
            ? null
            : {
                'effectiveSets': coverage.completedEffectiveSets,
                'dataQuality': coverage.dataQuality.name,
              },
        'progressionSummary': const {},
      },
    );
    final styledObservations = _applyStyle(
      observations.join('\n'),
      memories,
      dataLead:
          '${training.sessionCount} 次训练 · ${training.effectiveSets} 个有效组 · 饮食 ${nutrition.recordedDays}/7 天',
    );
    final validated = _validate(
      context,
      answer: styledObservations,
      summary: insufficient ? '记录不足，先继续积累' : '本周数据观察',
      uncertainties: [
        if (partial) AiCoachUncertainty.partialData,
        if (insufficient) AiCoachUncertainty.insufficientEvidence,
      ],
    );
    return AiCoachScenarioExplanation(
      type: AiCoachScenarioType.weeklyReview,
      title: 'GOAT 本周观察',
      headline: insufficient ? '记录不足，先继续积累' : '本周数据观察',
      explanation: styledObservations,
      evidence: [
        AiCoachEvidenceItem(
          id: 'weekly_review',
          label: '本周记录',
          value:
              '${training.trainingDays} 个训练日 · ${training.sessionCount} 次训练 · 饮食 ${nutrition.recordedDays}/7 天',
        ),
        if (coverage != null)
          AiCoachEvidenceItem(
            id: 'coverage_result',
            label: '覆盖统计',
            value: '${coverage.completedEffectiveSets} 个有效组',
          ),
      ],
      knowledge: _validatedKnowledge(context, validated),
      followUps: const ['本周数据够完整吗？', '下周最值得关注什么？'],
      suggestions: suggestions.take(3).toList(growable: false),
      uncertainties: validated.uncertainties,
    );
  }

  AiSuggestion restSuggestion({
    required String id,
    required String templateId,
    required String exerciseId,
    required String exerciseName,
    required int fixedSeconds,
    DateTime? createdAt,
  }) => AiSuggestion(
    id: id,
    type: AiSuggestionType.rest,
    title: '固定 $exerciseName 休息时间',
    summary: '将训练方案中的 $exerciseName 固定休息调整为 ${_duration(fixedSeconds)}。',
    reasonCodes: const ['weekly_review_rest_consistency'],
    evidenceRefs: const ['weekly_review'],
    knowledgeRefs: const ['kb_rest_user_override'],
    proposedAction: AiProposedAction(
      type: AiProposedActionType.updateRestPrescription,
      domainEntityId: templateId,
      payload: {
        'templateId': templateId,
        'exerciseId': exerciseId,
        'fixedSeconds': fixedSeconds,
      },
    ),
    dataQuality: AiSuggestionDataQuality.medium,
    status: AiSuggestionStatus.proposed,
    createdAt: createdAt ?? DateTime.now(),
  );

  AssembledAiContext _context({
    required AiCoachTaskType task,
    required String query,
    required List<String> reasonCodes,
    required List<AiMemoryItem> memories,
    required Map<String, dynamic> evidence,
    required Map<String, dynamic> taskContext,
  }) {
    final retrieved = retrieval.retrieve(
      KnowledgeRetrievalRequest(
        taskType: task,
        query: query,
        reasonCodes: reasonCodes,
        structuredContext: taskContext,
      ),
    );
    return assembler.assemble(
      AiContextRequest(
        taskType: task,
        memories: memories,
        retrievedKnowledge: retrieved,
        dataEvidence: evidence,
        currentTaskContext: taskContext,
      ),
    );
  }

  AiCoachResponse _validate(
    AssembledAiContext context, {
    required String answer,
    required String summary,
    List<AiCoachUncertainty> uncertainties = const [],
  }) => validator.validate(
    AiCoachResponse(
      answer: answer,
      summary: summary,
      evidenceRefs: context.allowedEvidenceRefs.toList(),
      knowledgeRefs: context.allowedKnowledgeRefs.toList(),
      uncertainties: uncertainties,
    ),
    context,
  );

  List<KnowledgeEntry> _validatedKnowledge(
    AssembledAiContext context,
    AiCoachResponse response,
  ) {
    final allowed = response.knowledgeRefs.toSet();
    final raw = context.payload['retrievedKnowledge'];
    if (raw is! List) return const [];
    final byId = retrieval.entries.where((e) => allowed.contains(e.id));
    return byId.toList(growable: false);
  }

  String _nutritionEvidence(WeeklyNutritionReview review) {
    if (review.recordedDays == 0) return '0 / 7 天，暂无营养平均值';
    return [
      '${review.recordedDays} / 7 天',
      if (review.averageCalories != null)
        '平均 ${review.averageCalories!.round()} kcal',
      if (review.averageProtein != null)
        '蛋白质 ${review.averageProtein!.round()} g',
    ].join(' · ');
  }

  String _trendEvidence(WeeklyNutritionReview review) {
    final trend = review.weightTrend;
    if (trend.sevenDayAverageKg == null) return '趋势暂不可用';
    final change = trend.change7dKg;
    return '${trend.sevenDayAverageKg!.toStringAsFixed(2)} kg'
        '${change == null ? '' : ' · 7 天 ${_signedDouble(change)} kg'}';
  }

  String _progressionExplanation(ProgressionRecommendation recommendation) {
    final reasons = recommendation.reasons;
    return switch (recommendation.type) {
      ProgressionRecommendationType.increaseWeight =>
        '目标组表现与次数余量满足递进规则，因此引擎给出增加重量；具体重量仍以引擎结果为准。',
      ProgressionRecommendationType.increaseReps =>
        '当前更适合先提高目标次数完成度，GOAT 不会在次数尚未稳定时改写为加重量。',
      ProgressionRecommendationType.keep =>
        reasons.contains(ProgressionReason.targetRepsIncomplete)
            ? '仍有工作组尚未稳定完成目标次数，本次保持重量有助于先稳定全部目标组。'
            : '当前历史与目标完成度更支持保持，GOAT 不会把 keep 改写为增加重量。',
      ProgressionRecommendationType.decreaseWeight =>
        '近期表现包含未达到最低目标或力竭信号，引擎因此建议降低重量以恢复可完成范围。',
      ProgressionRecommendationType.insufficientData =>
        '可靠同动作历史不足，GOAT 暂不推断下一次重量或次数。',
    };
  }

  String _restExplanation(
    RestRecommendation recommendation, {
    required String exerciseName,
    required int? rir,
    required bool reachedFailure,
  }) {
    if (recommendation.source == RestSource.templateFixed) {
      return '$exerciseName 当前使用用户在训练方案中设置的固定休息；GOAT 推荐值只用于解释，不会覆盖固定设置。';
    }
    if (recommendation.source == RestSource.sessionExerciseOverride) {
      return '$exerciseName 当前使用本次训练覆盖值，这个修改不会自动写回训练方案。';
    }
    final effort = reachedFailure
        ? '本组达到力竭'
        : rir == 0 ||
              recommendation.reasonCodes.contains(RestReasonCode.rirZero)
        ? '本组接近力竭（RIR 0）'
        : '本组状态';
    return '$exerciseName 的基础休息为 ${recommendation.baseSeconds} 秒，$effort带来 ${_signed(recommendation.modifierSeconds)} 秒修正，因此规则引擎给出 ${recommendation.recommendedSeconds} 秒。';
  }

  String _coverageExplanation(
    TrainingCoverageResult coverage,
    ExerciseRecommendationResult candidate,
    MuscleRegion? selectedRegion,
  ) {
    final movement = coverage.movement(candidate.movementPattern);
    final regionText = selectedRegion == null
        ? ''
        : '${muscleRegionLabel(selectedRegion)}当前覆盖${coverageLevelLabel(coverage.region(selectedRegion).level)}，';
    return '$regionText${movementPatternLabel(candidate.movementPattern)}当前有 ${movement.effectiveSetCount} 个有效组。${candidate.exercise.name}来自动作推荐引擎，用于补充已识别的覆盖或动作模式差异。';
  }

  String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  String _signed(int value) => value >= 0 ? '+$value' : '$value';

  String _signedDouble(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _applyStyle(
    String explanation,
    List<AiMemoryItem> memories, {
    required String dataLead,
  }) {
    final style = memories
        .where(
          (item) =>
              item.isUsableInContext &&
              item.category == AiProfileCategory.coachingStyle,
        )
        .map((item) => item.value)
        .firstOrNull;
    if (style == null || style.contains('详细')) return explanation;
    if (style.contains('简洁')) {
      return explanation.split(RegExp(r'[。！？\n]')).first.trim();
    }
    if (style.contains('数据')) return '$dataLead。$explanation';
    if (style.contains('鼓励')) {
      return '$explanation 保持克制地按当前规则执行即可。';
    }
    return explanation;
  }
}

extension _WeightTrendJson on WeightTrend {
  Map<String, dynamic> toJson() {
    return {
      'anchorDate': anchorDate.toIso8601String(),
      'sevenDayAverageKg': sevenDayAverageKg,
      'change7dKg': change7dKg,
      'change14dKg': change14dKg,
      'dataQuality': dataQuality.name,
      'readingCount': readingCount,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
