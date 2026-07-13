import 'package:flutter/material.dart';

class CalorieSummaryCard extends StatelessWidget {
  final double caloriesIn;
  final double caloriesBurn;
  final double netCalories;
  final double targetCalories;
  final VoidCallback onOpenSettings;

  const CalorieSummaryCard({
    super.key,
    required this.caloriesIn,
    required this.caloriesBurn,
    required this.netCalories,
    required this.targetCalories,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日热量概览',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Semantics(
                button: true,
                label: '设置每日热量目标',
                child: IconButton(
                  tooltip: '设置目标',
                  onPressed: onOpenSettings,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Colors.black38,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caloriesIn.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 42,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF008C8C),
            ),
          ),
          const Text(
            'kcal 已摄入',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Metric(label: '摄入', value: caloriesIn),
              _Metric(label: '消耗', value: caloriesBurn),
              _Metric(label: '净摄入', value: netCalories, highlight: true),
              _Metric(label: '目标', value: targetCalories),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black45),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: highlight ? const Color(0xFF008C8C) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
