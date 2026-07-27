import 'package:flutter/material.dart';

import '../../../models/rest_prescription.dart';
import '../../ai_coach/models/ai_memory.dart';
import '../../ai_coach/services/ai_coach_scenario_service.dart';
import '../../ai_coach/widgets/ai_evidence_sheet.dart';
import '../../ai_coach/widgets/ai_follow_up_sheet.dart';

class RestTimerCard extends StatelessWidget {
  const RestTimerCard({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.exerciseName,
    required this.nextSetLabel,
    required this.onStartNextSet,
    required this.onSkipRest,
    required this.onExtend,
    required this.onChangeExerciseRest,
    required this.onRestoreRecommended,
    this.recommendation,
    this.coachMemories = const [],
    this.setType,
    this.rir,
    this.reachedFailure = false,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String exerciseName;
  final String nextSetLabel;
  final VoidCallback onStartNextSet;
  final VoidCallback onSkipRest;
  final VoidCallback onExtend;
  final VoidCallback onChangeExerciseRest;
  final VoidCallback onRestoreRecommended;
  final RestRecommendation? recommendation;
  final List<AiMemoryItem> coachMemories;
  final String? setType;
  final int? rir;
  final bool reachedFailure;

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  String get _recommendationLabel {
    final value = recommendation;
    if (value == null) return '计划 ${_formatSeconds(totalSeconds)}';
    if (value.source == RestSource.templateFixed) {
      return '固定 ${_formatSeconds(value.plannedSeconds)}';
    }
    return 'GOAT 推荐 · ${_formatSeconds(value.recommendedSeconds)}';
  }

  String get _reasonLabel {
    final reasons = recommendation?.reasonCodes ?? const <RestReasonCode>[];
    const labels = {
      RestReasonCode.olympicPower: '高技术爆发动作',
      RestReasonCode.heavyCompound: '重型复合动作',
      RestReasonCode.standardCompound: '复合动作',
      RestReasonCode.machineCompound: '器械复合动作',
      RestReasonCode.isolation: '孤立动作',
      RestReasonCode.smallMuscleIsolation: '小肌群动作',
      RestReasonCode.warmupLowLoad: '低负荷热身组',
      RestReasonCode.warmupMediumLoad: '热身组',
      RestReasonCode.warmupHighLoad: '高负荷热身组',
      RestReasonCode.finalWarmup: '最后热身组，准备正式组',
      RestReasonCode.rirOne: '本组接近力竭，已延长 0:30',
      RestReasonCode.rirZero: '本组接近力竭，已延长 1:00',
      RestReasonCode.reachedFailure: '本组达到力竭，已延长恢复',
      RestReasonCode.dropSet: '递减组，已延长恢复',
      RestReasonCode.amrapSet: 'AMRAP 组，已延长恢复',
      RestReasonCode.failureSet: '力竭组，已延长恢复',
      RestReasonCode.exerciseTransition: '动作切换恢复',
      RestReasonCode.sameBodyPartTransition: '同部位动作切换',
      RestReasonCode.differentBodyPartTransition: '不同部位动作切换',
      RestReasonCode.nextHeavyExercise: '即将进入重型动作',
      RestReasonCode.supersetTransition: '超级组动作切换',
      RestReasonCode.supersetCycleRest: '超级组循环恢复',
      RestReasonCode.userFixed: '训练方案固定时间',
      RestReasonCode.sessionOverride: '本次训练设置',
    };
    for (final preferred in const [
      RestReasonCode.sessionOverride,
      RestReasonCode.rirZero,
      RestReasonCode.reachedFailure,
      RestReasonCode.failureSet,
      RestReasonCode.finalWarmup,
      RestReasonCode.nextHeavyExercise,
      RestReasonCode.supersetCycleRest,
      RestReasonCode.sameBodyPartTransition,
      RestReasonCode.differentBodyPartTransition,
      RestReasonCode.rirOne,
      RestReasonCode.dropSet,
      RestReasonCode.amrapSet,
    ]) {
      if (reasons.contains(preferred)) return labels[preferred]!;
    }
    return reasons.isEmpty ? '按当前训练情境安排' : labels[reasons.first]!;
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    return Column(
      key: const Key('rest-timer-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1017211E),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                '休息中',
                style: TextStyle(
                  color: Color(0xFF008C8C),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                key: const Key('rest-recommendation-explanation'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3F1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    Text(
                      _recommendationLabel,
                      style: const TextStyle(
                        color: Color(0xFF008C8C),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reasonLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF68716F),
                        fontSize: 12,
                      ),
                    ),
                    if (recommendation != null) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          TextButton(
                            key: const Key('rest-detailed-explanation'),
                            onPressed: () {
                              final explanation = const AiCoachScenarioService()
                                  .rest(
                                    recommendation: recommendation!,
                                    exerciseName: exerciseName,
                                    memories: coachMemories,
                                    setType: setType,
                                    rir: rir,
                                    reachedFailure: reachedFailure,
                                  );
                              AiEvidenceSheet.show(context, explanation);
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('详细解释 ›'),
                          ),
                          TextButton(
                            key: const Key('rest-follow-up'),
                            onPressed: () {
                              final explanation = const AiCoachScenarioService()
                                  .rest(
                                    recommendation: recommendation!,
                                    exerciseName: exerciseName,
                                    memories: coachMemories,
                                    setType: setType,
                                    rir: rir,
                                    reachedFailure: reachedFailure,
                                  );
                              AiFollowUpSheet.show(context, explanation);
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('问 GOAT'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('rest-extend-30'),
                  onPressed: onExtend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF008C8C),
                    side: const BorderSide(color: Color(0xFFD5E3E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+30 秒 · 仅本次'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 184,
                height: 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFE8EEEC),
                        color: const Color(0xFF008C8C),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatSeconds(remainingSeconds),
                          style: const TextStyle(
                            color: Color(0xFF1F2725),
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          '剩余休息',
                          style: TextStyle(
                            color: Color(0xFF8A9290),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '下一组',
                      style: TextStyle(color: Color(0xFF8A9290), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2725),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextSetLabel,
                      style: const TextStyle(
                        color: Color(0xFF68716F),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('rest-start-next-set'),
                  onPressed: onStartNextSet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF008C8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '开始下一组',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  TextButton(
                    key: const Key('rest-skip'),
                    onPressed: onSkipRest,
                    child: const Text('跳过休息'),
                  ),
                  TextButton(
                    key: const Key('rest-duration-button'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (sheetContext) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                key: const Key('rest-change-exercise-duration'),
                                leading: const Icon(Icons.tune),
                                title: const Text('修改本动作休息'),
                                subtitle: const Text('本次训练后续组继续使用'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  onChangeExerciseRest();
                                },
                              ),
                              if (recommendation?.isUserOverridden == true)
                                ListTile(
                                  key: const Key('rest-restore-recommendation'),
                                  leading: const Icon(Icons.refresh),
                                  title: const Text('恢复 GOAT 推荐'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    onRestoreRecommended();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: const Text('更多'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
