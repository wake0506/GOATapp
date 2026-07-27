import 'package:flutter/material.dart';

import '../../../models/progression_target.dart';
import '../../ai_coach/models/ai_memory.dart';
import '../../ai_coach/services/ai_coach_scenario_service.dart';
import '../../ai_coach/widgets/ai_coach_explanation_card.dart';
import '../../analytics/models/progression_recommendation.dart';

class TrainingRecommendationCard extends StatelessWidget {
  const TrainingRecommendationCard({
    super.key,
    required this.target,
    required this.recommendation,
    this.referenceWeightKg,
    this.onApply,
    this.coachMemories = const [],
    this.exerciseName = '当前动作',
  });

  final ProgressionTarget? target;
  final ProgressionRecommendation? recommendation;
  final double? referenceWeightKg;
  final VoidCallback? onApply;
  final List<AiMemoryItem> coachMemories;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    if (target == null) {
      return _shell(
        key: const Key('training-recommendation-missing-target'),
        children: const [
          Text(
            'GOAT 建议',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            '暂无精确递进建议',
            style: TextStyle(color: Color(0xFF4C5553), fontSize: 13),
          ),
          SizedBox(height: 3),
          Text(
            '在训练方案中设置目标后，可结合历史表现生成建议。',
            style: TextStyle(color: Color(0xFF858D8B), fontSize: 11),
          ),
        ],
      );
    }
    final result = recommendation;
    if (result == null) return const SizedBox.shrink();
    return _shell(
      key: const Key('training-recommendation-card'),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'GOAT 建议',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              _qualityLabel(result.dataQuality),
              style: const TextStyle(color: Color(0xFF8A9290), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _actionLabel(result, referenceWeightKg),
          key: const Key('training-recommendation-action'),
          style: const TextStyle(
            color: Color(0xFF1F2725),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _targetLabel(target!),
          style: const TextStyle(color: Color(0xFF69716F), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              key: const Key('training-recommendation-reasons'),
              onPressed: () => _showReasons(context, result),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('查看原因 ›'),
            ),
            const Spacer(),
            if (result.suggestedWeightKg != null && onApply != null)
              TextButton(
                key: const Key('training-recommendation-apply'),
                onPressed: onApply,
                child: const Text('采用建议'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _shell({required Key key, required List<Widget> children}) =>
      Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE9E6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  String _actionLabel(
    ProgressionRecommendation result,
    double? referenceWeightKg,
  ) => switch (result.type) {
    ProgressionRecommendationType.increaseWeight =>
      result.suggestedWeightKg == null
          ? '可以增加重量'
          : '建议下次 ${result.suggestedWeightKg!.toStringAsFixed(1)} kg',
    ProgressionRecommendationType.increaseReps => '优先增加完成次数',
    ProgressionRecommendationType.keep =>
      referenceWeightKg == null
          ? '保持当前重量'
          : '保持 ${referenceWeightKg.toStringAsFixed(1)} kg',
    ProgressionRecommendationType.decreaseWeight => '建议适当降低重量',
    ProgressionRecommendationType.insufficientData => '数据不足，暂不生成递进建议',
  };

  String _targetLabel(ProgressionTarget target) =>
      '目标 ${target.targetSets}×${target.targetRepMin}–${target.targetRepMax}';

  String _qualityLabel(ProgressionDataQuality quality) => switch (quality) {
    ProgressionDataQuality.high => '数据充分',
    ProgressionDataQuality.medium => '数据一般',
    ProgressionDataQuality.low => '历史数据有限',
    ProgressionDataQuality.insufficient => '数据不足',
  };

  Future<void> _showReasons(
    BuildContext context,
    ProgressionRecommendation result,
  ) {
    final explanation = const AiCoachScenarioService().progression(
      recommendation: result,
      exerciseName: exerciseName,
      memories: coachMemories,
      target: target,
      referenceWeightKg: referenceWeightKg,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            key: const Key('training-recommendation-reason-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '建议依据',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final reason in result.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${_reasonLabel(reason)}',
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                result.basedOnSessionDate == null
                    ? '依据：当前可用的同动作历史'
                    : '依据：${_dateLabel(result.basedOnSessionDate!)} 的同动作训练',
                style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
              ),
              const SizedBox(height: 16),
              AiCoachExplanationCard(
                key: const Key('progression-ai-explanation'),
                explanation: explanation,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _reasonLabel(ProgressionReason reason) => switch (reason) {
    ProgressionReason.allTargetRepsCompleted => '主要工作组均达到目标次数上限',
    ProgressionReason.highRirReserve => '已记录的工作组仍有足够次数余量',
    ProgressionReason.targetRepsIncomplete => '仍有工作组尚未稳定达到目标次数',
    ProgressionReason.reachedFailure => '历史记录包含接近力竭或力竭表现',
    ProgressionReason.repeatedUnderperformance => '连续训练未达到最低目标次数',
    ProgressionReason.missingRir => '部分历史缺少 RIR，建议更保守',
    ProgressionReason.missingProgressionTarget => '尚未设置递进目标',
    ProgressionReason.insufficientHistory => '同动作历史记录不足',
    ProgressionReason.supersetContext => '依据包含超级组训练，疲劳背景可能不同',
    ProgressionReason.legacyNameMatch => '依据旧历史中的同名动作匹配',
  };

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
