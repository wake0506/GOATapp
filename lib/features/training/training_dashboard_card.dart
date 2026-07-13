import 'package:flutter/material.dart';

import 'training_dashboard_data.dart';

class TrainingDashboardCard extends StatelessWidget {
  final TrainingDashboardData data;

  const TrainingDashboardCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final latest = data.latestSession;
    return Semantics(
      label: '训练概览',
      child: Container(
        key: const Key('training-dashboard-card'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fitness_center_rounded, color: Color(0xFF008C8C)),
                SizedBox(width: 8),
                Text(
                  '训练概览',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Metric(label: '今日训练', value: '${data.todaySessions.length} 次'),
                _Metric(label: '本周训练', value: '${data.weekCount} 次'),
                _Metric(
                  label: '最近一次',
                  value: latest == null ? '暂无' : latest.date,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              latest == null ? '还没有训练记录，从一个训练模板开始' : '最近训练：${latest.name}',
              style: const TextStyle(color: Color(0xFF70757A), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF008C8C),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF70757A), fontSize: 12),
        ),
      ],
    ),
  );
}
