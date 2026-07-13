import 'package:flutter/material.dart';

import 'training_dashboard_data.dart';

class TrainingStatsRow extends StatelessWidget {
  final TrainingDashboardData data;

  const TrainingStatsRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '训练统计',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (!data.hasSessions)
        const Text(
          '记录训练后，这里会显示近 7 天的训练概览。',
          style: TextStyle(color: Color(0xFF70757A), fontSize: 13),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _Stat(value: '${data.weekCount}', label: '本周训练'),
              _Stat(value: '${data.monthCount}', label: '本月训练'),
              _Stat(value: '${data.recentExerciseCount}', label: '近 7 天动作'),
            ],
          ),
        ),
    ],
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF008C8C),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF70757A), fontSize: 11),
        ),
      ],
    ),
  );
}
