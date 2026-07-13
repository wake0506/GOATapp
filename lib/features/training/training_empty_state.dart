import 'package:flutter/material.dart';

class TrainingEmptyState extends StatelessWidget {
  const TrainingEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('training-empty-state'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.route_outlined, color: Color(0xFF008C8C)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('开始你的第一节训练', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 5),
              Text(
                '从常见训练部位开始，快速建立自己的训练结构。记录一次训练后，这里会逐步形成你的训练轨迹。',
                style: TextStyle(
                  color: Color(0xFF70757A),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
