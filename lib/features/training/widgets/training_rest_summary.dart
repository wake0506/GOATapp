import 'package:flutter/material.dart';

import '../../../models/training.dart';

class TrainingRestSummary extends StatelessWidget {
  const TrainingRestSummary({super.key, required this.session});

  final TrainingSession session;

  String _average(Iterable<int?> values) {
    final tracked = values.whereType<int>().toList(growable: false);
    if (tracked.isEmpty) return '--';
    final seconds =
        tracked.reduce((sum, value) => sum + value) ~/ tracked.length;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sets = session.exercises.expand((exercise) => exercise.sets);
    final planned = _average(sets.map((set) => set.plannedRestSeconds));
    final actual = _average(sets.map((set) => set.actualRestSeconds));
    return Container(
      key: const Key('training-detail-rest-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RestFact(label: '计划平均', value: planned),
          ),
          const SizedBox(height: 32, child: VerticalDivider(width: 1)),
          Expanded(
            child: _RestFact(label: '实际平均', value: actual),
          ),
        ],
      ),
    );
  }
}

class _RestFact extends StatelessWidget {
  const _RestFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8A9290), fontSize: 11),
      ),
    ],
  );
}
