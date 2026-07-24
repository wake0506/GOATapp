import '../models/knowledge_entry.dart';

class GoatKnowledgeBaseV1 {
  GoatKnowledgeBaseV1._();

  static const entries = <KnowledgeEntry>[
    KnowledgeEntry(
      id: 'kb_training_effective_set_v1',
      category: KnowledgeCategory.trainingPrinciples,
      title: '有效训练组',
      content: 'GOAT 的有效组统计由 Effective Set V1 规则计算，AI 只解释结果，不重新判定。',
      tags: ['effective_set', 'working_set', '训练组'],
      applicableContexts: ['training', 'weekly_review'],
      stablePriority: 8,
    ),
    KnowledgeEntry(
      id: 'kb_training_quality_over_count',
      category: KnowledgeCategory.trainingPrinciples,
      title: '训练质量优先',
      content: '训练组数量需要结合动作质量、目标次数与接近力竭程度理解，不能只看总组数。',
      tags: ['quality', 'rir', 'volume'],
      applicableContexts: ['training', 'weekly_review'],
    ),
    KnowledgeEntry(
      id: 'kb_training_history_boundary',
      category: KnowledgeCategory.trainingPrinciples,
      title: '历史数据边界',
      content: '历史记录不足时应明确数据不足，避免根据单次表现推断长期能力或人格。',
      tags: ['insufficient_data', 'history'],
      applicableContexts: ['training', 'profile'],
    ),
    KnowledgeEntry(
      id: 'kb_progression_engine_authority',
      category: KnowledgeCategory.progression,
      title: '递进结果由规则引擎决定',
      content: '增加重量、增加次数、保持或降低重量由 ProgressionRecommendationEngine 决定。',
      tags: ['progression', 'engine', 'deterministic'],
      applicableContexts: ['progression_explanation'],
      stablePriority: 10,
    ),
    KnowledgeEntry(
      id: 'kb_progression_keep_target_incomplete',
      category: KnowledgeCategory.progression,
      title: '未完成目标时保持',
      content: '当主要工作组尚未稳定完成目标次数时，保持当前重量通常是为了先完成既定目标。',
      tags: ['keep', 'target_incomplete', 'reps'],
      applicableContexts: ['progression_explanation'],
      stablePriority: 8,
    ),
    KnowledgeEntry(
      id: 'kb_progression_increase_boundary',
      category: KnowledgeCategory.progression,
      title: '增加负重边界',
      content: '只有规则引擎确认目标完成度、次数余量与历史质量满足条件时，才生成增加负重建议。',
      tags: ['increase_weight', 'rir', 'target_completed'],
      applicableContexts: ['progression_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_progression_confirmation',
      category: KnowledgeCategory.goatRuleExplanations,
      title: '递进建议需要确认',
      content: '递进建议是待确认操作；用户查看并确认后，领域服务仍需校验再保存。',
      tags: ['confirmation', 'apply_boundary', 'progression'],
      applicableContexts: ['progression_explanation', 'suggestion'],
    ),
    KnowledgeEntry(
      id: 'kb_rest_compound_longer',
      category: KnowledgeCategory.restAndRecovery,
      title: '复合动作休息更长',
      content: '复合动作通常动员更多肌群与整体力量，因此 GOAT 的基础恢复时间相对更长。',
      tags: ['standard_compound', 'heavy_compound', 'rest'],
      applicableContexts: ['rest_explanation'],
      stablePriority: 9,
    ),
    KnowledgeEntry(
      id: 'kb_rest_rir_zero_modifier',
      category: KnowledgeCategory.restAndRecovery,
      title: 'RIR 0 延长恢复',
      content: '本组记录为 RIR 0 时，Rest Prescription V2 在动作基础休息上增加 60 秒恢复。',
      tags: ['rir_zero', 'rest', 'modifier'],
      applicableContexts: ['rest_explanation'],
      stablePriority: 10,
    ),
    KnowledgeEntry(
      id: 'kb_rest_rir_one_modifier',
      category: KnowledgeCategory.restAndRecovery,
      title: 'RIR 1 延长恢复',
      content: '本组记录为 RIR 1 时，Rest Prescription V2 在动作基础休息上增加 30 秒恢复。',
      tags: ['rir_one', 'rest', 'modifier'],
      applicableContexts: ['rest_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_rest_final_warmup',
      category: KnowledgeCategory.restAndRecovery,
      title: '最后热身组恢复',
      content: '最后热身组后会增加恢复，以便在进入正式工作组前减少热身疲劳的干扰。',
      tags: ['final_warmup', 'warmup', 'rest'],
      applicableContexts: ['rest_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_rest_extend_once',
      category: KnowledgeCategory.goatRuleExplanations,
      title: '加 30 秒只影响本次',
      content: '休息卡上的加 30 秒属于单次临时延长，不修改训练方案或后续组的默认时间。',
      tags: ['session_override', 'extend_once', 'rest'],
      applicableContexts: ['rest_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_rest_user_override',
      category: KnowledgeCategory.goatRuleExplanations,
      title: '用户固定时间优先',
      content: '用户明确设置的固定休息时间优先于推荐值，但推荐值仍可用于说明系统默认依据。',
      tags: ['user_fixed', 'override', 'rest'],
      applicableContexts: ['rest_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_rest_engine_seconds_authority',
      category: KnowledgeCategory.goatRuleExplanations,
      title: 'AI 不改变休息秒数',
      content: '当前休息秒数由 Rest Prescription V2 计算；AI 只能解释，不能在回答中覆盖该结果。',
      tags: ['rest', 'engine', 'deterministic'],
      applicableContexts: ['rest_explanation'],
      stablePriority: 10,
    ),
    KnowledgeEntry(
      id: 'kb_exercise_engine_candidates',
      category: KnowledgeCategory.exerciseSelection,
      title: '动作候选来自目录',
      content: '动作建议只能使用 ExerciseRecommendationEngine 与已验证动作目录返回的候选。',
      tags: ['exercise_recommendation', 'catalog', 'candidate'],
      applicableContexts: ['exercise_selection', 'coverage_explanation'],
      stablePriority: 9,
    ),
    KnowledgeEntry(
      id: 'kb_exercise_complement_pattern',
      category: KnowledgeCategory.exerciseSelection,
      title: '补足动作模式',
      content: '动作选择会优先考虑当前计划中相对不足的动作模式与肌群覆盖，而不是随机增加动作。',
      tags: ['movement_pattern', 'coverage', 'exercise'],
      applicableContexts: ['exercise_selection', 'coverage_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_exercise_unresolved_metadata',
      category: KnowledgeCategory.exerciseSelection,
      title: '未解析动作的保守处理',
      content: '动作元数据未确认时，GOAT 不使用它生成精确的肌肉覆盖或互补动作结论。',
      tags: ['unresolved', 'metadata', 'guardrail'],
      applicableContexts: ['exercise_selection', 'coverage_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_coverage_meaning',
      category: KnowledgeCategory.trainingCoverage,
      title: '训练覆盖含义',
      content: '覆盖等级反映所选周期内不同肌群或动作模式的有效训练分布，不代表医学状态。',
      tags: ['coverage', 'effective_set', 'meaning'],
      applicableContexts: ['coverage_explanation'],
      stablePriority: 9,
    ),
    KnowledgeEntry(
      id: 'kb_coverage_balance',
      category: KnowledgeCategory.trainingCoverage,
      title: '覆盖平衡',
      content: '高覆盖与低覆盖用于帮助发现训练分布差异，是否调整仍需结合目标、恢复和用户选择。',
      tags: ['coverage', 'high', 'low', 'balance'],
      applicableContexts: ['coverage_explanation'],
    ),
    KnowledgeEntry(
      id: 'kb_weight_sma_7d',
      category: KnowledgeCategory.weightTrend,
      title: '七日趋势体重',
      content: 'GOAT 使用七日简单移动平均观察体重趋势，降低单日水分与测量波动的影响。',
      tags: ['trend_weight', '7_day_sma', 'weight'],
      applicableContexts: ['weight_trend'],
      stablePriority: 10,
    ),
    KnowledgeEntry(
      id: 'kb_weight_single_day_noise',
      category: KnowledgeCategory.weightTrend,
      title: '单日体重波动',
      content: '单日变化可能受水分、盐分、碳水和测量时间影响，不应直接当作长期趋势。',
      tags: ['weight', 'daily_noise', 'trend'],
      applicableContexts: ['weight_trend'],
    ),
    KnowledgeEntry(
      id: 'kb_nutrition_energy_context',
      category: KnowledgeCategory.nutritionGeneral,
      title: '热量需要结合目标',
      content: '摄入与目标的比较应结合用户设定、记录完整度和阶段目标，不根据单餐下长期结论。',
      tags: ['calorie', 'goal', 'data_quality'],
      applicableContexts: ['nutrition'],
      stablePriority: 7,
    ),
    KnowledgeEntry(
      id: 'kb_nutrition_protein_distribution',
      category: KnowledgeCategory.nutritionGeneral,
      title: '蛋白质记录看全天',
      content: '蛋白质建议优先观察全天总量与多餐分布，单餐缺口不等于全天不足。',
      tags: ['protein', 'daily_total', 'meal'],
      applicableContexts: ['nutrition'],
    ),
    KnowledgeEntry(
      id: 'kb_nutrition_ai_confirmation',
      category: KnowledgeCategory.goatRuleExplanations,
      title: 'AI 营养解析先预览',
      content: 'AI 解析的食物项目必须由用户预览确认后，才会写入正式饮食记录。',
      tags: ['nutrition_ai', 'confirmation', 'preview'],
      applicableContexts: ['nutrition', 'suggestion'],
      stablePriority: 8,
    ),
    KnowledgeEntry(
      id: 'kb_general_recovery_context',
      category: KnowledgeCategory.restAndRecovery,
      title: '恢复信息的边界',
      content: '训练恢复说明可以参考训练量、接近力竭和休息记录，但不能据此自动作医疗诊断。',
      tags: ['recovery', 'medical_boundary', 'training'],
      applicableContexts: ['rest_explanation', 'training'],
    ),
    KnowledgeEntry(
      id: 'kb_future_recovery_draft',
      category: KnowledgeCategory.restAndRecovery,
      title: '未来恢复规则草案',
      content: '该条目仅用于测试草案不会进入正式检索。',
      tags: ['draft'],
      applicableContexts: ['rest_explanation'],
      reviewStatus: KnowledgeReviewStatus.draft,
    ),
    KnowledgeEntry(
      id: 'kb_legacy_progression_deprecated',
      category: KnowledgeCategory.progression,
      title: '旧递进说明',
      content: '该旧版本已弃用，不能进入正式检索。',
      tags: ['deprecated'],
      applicableContexts: ['progression_explanation'],
      version: 0,
      reviewStatus: KnowledgeReviewStatus.deprecated,
    ),
  ];

  static KnowledgeIntegrityReport validate() {
    final ids = <String>{};
    final duplicates = <String>{};
    final invalid = <String>{};
    for (final entry in entries) {
      if (!ids.add(entry.id)) duplicates.add(entry.id);
      if (entry.id.trim().isEmpty ||
          entry.title.trim().isEmpty ||
          entry.content.trim().isEmpty ||
          entry.source.trim().isEmpty ||
          entry.version < 0) {
        invalid.add(entry.id);
      }
    }
    return KnowledgeIntegrityReport(
      total: entries.length,
      approved: entries
          .where((item) => item.reviewStatus == KnowledgeReviewStatus.approved)
          .length,
      draft: entries
          .where((item) => item.reviewStatus == KnowledgeReviewStatus.draft)
          .length,
      deprecated: entries
          .where(
            (item) => item.reviewStatus == KnowledgeReviewStatus.deprecated,
          )
          .length,
      duplicateIds: duplicates,
      invalidEntries: invalid,
    );
  }
}
