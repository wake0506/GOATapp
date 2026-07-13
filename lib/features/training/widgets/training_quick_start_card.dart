import 'package:flutter/material.dart';

import 'training_nested_action_row.dart';

class TrainingQuickStartCard extends StatelessWidget {
  const TrainingQuickStartCard({
    super.key,
    required this.onStartTraining,
    required this.onUsePplTemplate,
    required this.onUseFullBodyTemplate,
    required this.onViewHistory,
    required this.onManageTemplates,
  });

  final VoidCallback onStartTraining;
  final VoidCallback onUsePplTemplate;
  final VoidCallback onUseFullBodyTemplate;
  final VoidCallback onViewHistory;
  final VoidCallback onManageTemplates;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('training-quick-start-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17211E),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '开始一次新训练',
              child: InkWell(
                onTap: onStartTraining,
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fitness_center_outlined,
                      color: Color(0xFF004D3A),
                      size: 29,
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        '开始一次新训练',
                        style: TextStyle(
                          color: Color(0xFF1F2725),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Material(
                      color: const Color(0xFF005A45),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onStartTraining,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.add, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 5),
              child: Text(
                '我的常用方案',
                style: TextStyle(
                  color: Color(0xFF9AA1A3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            TrainingNestedActionRow(label: 'PPL-推力日', onTap: onUsePplTemplate),
            const Divider(height: 1, color: Color(0xFFF0F1F2)),
            TrainingNestedActionRow(
              label: '全身循环燃脂',
              onTap: onUseFullBodyTemplate,
            ),
            const Divider(height: 1, color: Color(0xFFF0F1F2)),
            TrainingNestedActionRow(label: '查看训练历史', onTap: onViewHistory),
            const Divider(height: 1, color: Color(0xFFF0F1F2)),
            TrainingNestedActionRow(label: '管理训练模板', onTap: onManageTemplates),
          ],
        ),
      ),
    );
  }
}
