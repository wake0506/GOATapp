import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/exercise_recommendation.dart';

class NextExerciseRecommendationCard extends StatelessWidget {
  const NextExerciseRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onApply,
    required this.onViewOther,
    required this.onIgnore,
  });

  final ExerciseRecommendationResult recommendation;
  final VoidCallback onApply;
  final VoidCallback onViewOther;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('next-exercise-recommendation-card'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE6ECEA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GOAT 建议',
          style: TextStyle(
            color: Color(0xFF008C8C),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '优先补充：${recommendation.exercise.name}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          _reason(recommendation),
          style: const TextStyle(color: Color(0xFF68716F), fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('next-exercise-recommendation-apply'),
                onPressed: onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                ),
                child: const Text('采用'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onViewOther, child: const Text('查看其他')),
            IconButton(
              key: const Key('next-exercise-recommendation-ignore'),
              tooltip: '忽略建议',
              onPressed: onIgnore,
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ),
      ],
    ),
  );

  String _reason(ExerciseRecommendationResult item) {
    if (item.reasonCodes.contains(
      ExerciseRecommendationReason.missingMovementPattern,
    )) {
      return '当前同类动作较多，可补充${movementPatternLabel(item.movementPattern)}。';
    }
    if (item.reasonCodes.contains(
      ExerciseRecommendationReason.undercoveredPrimaryRegion,
    )) {
      final region = item.targetRegions.isEmpty
          ? '目标区域'
          : muscleRegionLabel(item.targetRegions.first);
      return '本次训练中 $region 相对覆盖较少，可进一步补充。';
    }
    return '符合本次训练目标，是否加入由你决定。';
  }
}

class ExerciseRecommendationSheet extends StatelessWidget {
  const ExerciseRecommendationSheet({super.key, required this.recommendations});

  final List<ExerciseRecommendationResult> recommendations;

  static Future<ExerciseRecommendationResult?> show(
    BuildContext context, {
    required List<ExerciseRecommendationResult> recommendations,
  }) => showModalBottomSheet<ExerciseRecommendationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ExerciseRecommendationSheet(
      recommendations: recommendations.take(5).toList(growable: false),
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            '其他建议',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final item in recommendations)
          ListTile(
            key: Key('exercise-recommendation-option-${item.exercise.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(item.exercise.name),
            subtitle: Text(
              '${item.targetRegions.take(2).map(muscleRegionLabel).join(' · ')} · ${movementPatternLabel(item.movementPattern)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, item),
          ),
      ],
    ),
  );
}
