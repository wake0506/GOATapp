import 'package:flutter/material.dart';

class TrainingQuickActions extends StatelessWidget {
  final VoidCallback onStartTraining;
  final VoidCallback onAddRecord;
  final VoidCallback onAddTemplate;
  final VoidCallback onViewHistory;

  const TrainingQuickActions({
    super.key,
    required this.onStartTraining,
    required this.onAddRecord,
    required this.onAddTemplate,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '快捷操作',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Action(
            label: '开始训练',
            icon: Icons.play_arrow_rounded,
            onTap: onStartTraining,
          ),
          _Action(
            label: '添加记录',
            icon: Icons.add_task_rounded,
            onTap: onAddRecord,
          ),
          _Action(
            label: '训练模板',
            icon: Icons.bookmark_add_outlined,
            onTap: onAddTemplate,
          ),
          _Action(
            label: '查看历史',
            icon: Icons.history_rounded,
            onTap: onViewHistory,
          ),
        ],
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Action({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF008C8C),
        side: const BorderSide(color: Color(0x33008C8C)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
