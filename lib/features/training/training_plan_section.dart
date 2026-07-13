import 'package:flutter/material.dart';

import 'training_dashboard_data.dart';

class TrainingPlanSection extends StatelessWidget {
  final TrainingDashboardData data;
  final VoidCallback onCreatePlan;

  const TrainingPlanSection({
    super.key,
    required this.data,
    required this.onCreatePlan,
  });

  @override
  Widget build(BuildContext context) {
    final latest = data.latestSession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '训练计划',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          key: const Key('training-plan-section'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: latest == null
              ? Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: Color(0xFF008C8C),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '建立你的训练结构',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '从一个部位模板开始，再逐步调整为自己的节奏。',
                            style: TextStyle(
                              color: Color(0xFF70757A),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onCreatePlan,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF008C8C),
                      ),
                      tooltip: '创建训练计划',
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.bookmark_added_outlined,
                      color: Color(0xFF008C8C),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '已保留 ${data.recentSessions.length} 条训练结构，最近为 ${latest.name}。',
                        style: const TextStyle(
                          color: Color(0xFF4A4F55),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
