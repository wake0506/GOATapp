import 'package:flutter/material.dart';

import 'dashboard_data.dart';

class ActivitySummaryCard extends StatelessWidget {
  final DashboardActivitySummary activity;
  final VoidCallback onOpenTraining;
  final VoidCallback onAddExercise;

  const ActivitySummaryCard({
    super.key,
    required this.activity,
    required this.onOpenTraining,
    required this.onAddExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpenTraining,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_outlined,
                    color: Colors.deepOrangeAccent,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '今日运动与训练',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '记录运动',
                    onPressed: onAddExercise,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF008C8C),
                      size: 22,
                    ),
                  ),
                ],
              ),
              Text(
                '${activity.exerciseCalories.toStringAsFixed(0)} kcal · ${activity.exerciseCount} 次运动 · ${activity.trainingSessionCount} 次训练',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (activity.exerciseNames.isEmpty &&
                  activity.trainingNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Text(
                    '暂无记录',
                    style: TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                )
              else ...[
                const SizedBox(height: 7),
                Text(
                  [
                    ...activity.exerciseNames,
                    ...activity.trainingNames,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
